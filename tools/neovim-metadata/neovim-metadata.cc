/**
 * \file neovim-metadata.cc
 * \brief LLVM/Clang plugin for generating MsgPack RPC metadata.
 *
 * In order to obtain metadata from sample.c one should run the following.
 * $ clang \
 *      -c \
 *      -std=gnu99 \
 *      -DDEFINE_FUNC_ATTRIBUTES \
 *      -I/path/to/neovim/git/repo/neovim/src \
 *      -I/path/to/neovim/git/repo/neovim/build/config \
 *      -I/path/to/neovim/git/repo/neovim/build/src \
 *      -Xclang -load -Xclang $(pwd)/neovim-meta.so -Xclang -plugin -Xclang neovim-meta \
 *      sample.c
 */

#include <string>
#include <vector>

#include <clang/Frontend/FrontendPluginRegistry.h>
#include <clang/AST/AST.h>
#include <clang/AST/ASTConsumer.h>
#include <clang/AST/RecursiveASTVisitor.h>
#include <clang/Frontend/CompilerInstance.h>
#include <clang/Sema/Sema.h>
#include <llvm/Support/raw_ostream.h>

#include "helpers.cc"

using namespace clang;

namespace {

struct Argument {
    std::string type;
    std::string name;

    std::string getAsJSONString(void) const {
        return "[\"" + type + "\",\"" + name + "\"]";
    }
};

struct Method {
    std::string name;
    std::string return_type;
    std::vector<Argument> arguments;
    size_t since;
};

std::string getAsJSONString(const std::vector<Argument> &args) {
    std::string json = "[";

    if (args.size() > 0) {
        json += args.front().getAsJSONString();
    }

    for (size_t i = 1; i < args.size(); ++i) {
        json += "," + args[i].getAsJSONString();
    }

    return json + "]";
}

class RPCMetaConsumer : public ASTConsumer {
    CompilerInstance &Instance;
    std::vector<Method> &Methods;

public:
    RPCMetaConsumer(CompilerInstance &Instance, std::vector<Method> &Methods)
        : Instance(Instance), Methods(Methods) {}

    bool HandleTopLevelDecl(DeclGroupRef group) override {
        auto &context= Instance.getASTContext();
        auto &srcmgr = context.getSourceManager();

        for (const auto *decl : group) {
            if (!srcmgr.isInMainFile(decl->getLocation())) {
                continue;
            }

            if (const FunctionDecl *func= dyn_cast<FunctionDecl>(decl)) {
                HandleFunctions(func);
            }
        }

        return true;
    }

private:
    inline bool IsRemoteProcedure(const std::string &code) const {
        size_t pos = code.find("FUNC_API_SINCE");
        return pos != std::string::npos;
    }

    void HandleFunctions(const FunctionDecl *func) {
        auto &context= Instance.getASTContext();
        auto &srcmgr = context.getSourceManager();

        SourceLocation funcBegin = func->getSourceRange().getBegin();
        SourceLocation funcEnd = func->getSourceRange().getEnd();
        SourceLocation bodyBegin = func->getBody()->getBeginLoc();

        std::string code(srcmgr.getCharacterData(funcBegin),
                         srcmgr.getCharacterData(bodyBegin));

        if (!IsRemoteProcedure(code)) {
            return;
        }

        Method method = {
            .name = func->getNameAsString(),
            .return_type = getReturnType(code, func->getNameAsString()),
            .since = *getAPILevel(code),
        };

        for (auto parameter : func->parameters()) {
            method.arguments.push_back({
                .type = parameter->getType().getAsString(),
                .name = parameter->getNameAsString(),
            });
        }

        Methods.emplace_back(std::move(method));
    }
};

class RPCMetaAction : public PluginASTAction {
    std::vector<Method> Methods;

protected:
    std::unique_ptr<ASTConsumer> CreateASTConsumer(CompilerInstance &CI,
                                                   llvm::StringRef) override {
        return llvm::make_unique<RPCMetaConsumer>(CI, Methods);
    }

    void EndSourceFileAction(void) override {
        for (auto &method : Methods) {
            std::string parameters = getAsJSONString(method.arguments);
            std::string item;

            item += "{";
            item += "\"name\":\"" + method.name + "\",";
            item += "\"parameters\":" + parameters + ",";
            item += "\"return_type\":\"" + method.return_type + "\",";
            item += "\"since\":" + std::to_string(method.since);
            item += "}";

            llvm::outs() << item << "\n";
        }
    }

    bool ParseArgs(const CompilerInstance &CI,
                   const std::vector<std::string> &args) override {
        // TODO(@daskol): Parse plugin argument. For example, output directory
        // or metadata output format.

        if (args.size() > 0) {
            PrintHelp(llvm::errs());
        }

        return true;
    }

    void PrintHelp(llvm::raw_ostream& ros) {
        ros << "RPCMeta plugin collect metadata for MsgPack RPC.\n";
    }
};

} // namespace

static FrontendPluginRegistry::Add<RPCMetaAction>
    RPCMetaPlugin("neovim-metadata", "gather neovim msgpack rpc metadata");
