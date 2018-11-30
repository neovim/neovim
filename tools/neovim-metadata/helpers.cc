/**
 * \file helpers.cc
 * \brief Routines for extraction API level.
 */
#include <algorithm>
#include <charconv>
#include <functional>
#include <iostream>
#include <locale>
#include <optional>
#include <string>

namespace {

inline void ltrim(std::string &s) {
    s.erase(s.begin(), std::find_if(s.begin(), s.end(),
            std::not1(std::ptr_fun<int, int>(std::isspace))));
}

inline void rtrim(std::string &s) {
    s.erase(std::find_if(s.rbegin(), s.rend(),
            std::not1(std::ptr_fun<int, int>(std::isspace))).base(), s.end());
}

inline std::string &trim(std::string &str) {
    ltrim(str);
    rtrim(str);
    return str;
}

std::optional<size_t> getAPILevel(const std::string &code) {
    const std::string needle("FUNC_API_SINCE");
    size_t pos = code.find("FUNC_API_SINCE");

    if (pos == std::string::npos) {
        return std::nullopt;
    }

    // Locate argument of macro.
    size_t lparen = 0, rparen = 0;

    for (size_t i = pos + needle.size(); i != code.size(); ++i) {
        // Find the left parenthesis.
        if (lparen == 0 && code[i] == '(') {
            lparen = i;
            continue;
        }

        // Find the right parenthesis.
        if (lparen != 0 && code[i] == ')') {
            rparen = i;
            break;
        }
    }

    if (lparen == 0 || rparen == 0) {
        return std::nullopt;
    }

    // Parse argument of macro.
    const char *begin = code.c_str() + lparen + 1;
    const char *end = code.c_str() + rparen;
    int api_level = 0;
    auto res = std::from_chars(begin, end, api_level);

    if (res.ec == std::errc::invalid_argument ||
        res.ec == std::errc::result_out_of_range) {
        return std::nullopt;
    } else {
        return api_level;
    }
}

std::string getReturnType(const std::string &code, const std::string &func) {
    size_t pos = code.find(func);

    if (pos == std::string::npos) {
        return ""; // This is impossible path.
    }

    std::string return_type = code.substr(0, pos);
    return trim(return_type);
}

} // namespace
