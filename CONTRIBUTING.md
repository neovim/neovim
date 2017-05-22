# Neovim 기여

시작하기
---------------

도움을 주고 싶지만 어디서부터 시작해야 할지 모르겠다면 위험성이 낮은 작업을 다음과 같이 하십시오. 

- 병합 [Vim 패치].
- [복잡성 : 낮음] 문제를 사용해보십시오.
- [clang-scan], [coverity] (# coverity) 및 [PVS] (# pvs-studio)에서 발견 된 버그를 수정했습니다.
 
개발자 가이드라인
--------------------

- Nvim 개발자는 ':help dev-help'를 읽어야 합니다.
- 외부 UI 개발자는 ':help dev-ui'를 읽어야 합니다.

문제 보고
------------------

- [** FAQ **] [wiki-faq]를 확인하십시오.
- [기존 문제][github-issues]검색 (닫음 포함)
- Neovim을 최신 버전으로 업데이트하여 문제가 지속되는지 확인하십시오.
- 플러그인 관리자를 사용하는 경우 플러그인을 주석으로 처리 한 다음 하나씩 다시 추가하여 문제의 원인을 좁힙니다.
- 스택 추적을 포함하는 오류 보고서는 10배 더 가치가 있습니다.
- 퇴행의 원인에 대해 [git-bisect]을 [Bisecting] 하면 종종 즉각적인 수정이 이루어집니다.
 
당겨받기 요청 ("PRs")
---------------------

- 중복 작업을 피하려면 가능한 한 빨리 '[WIP]' pull 요청을 만드십시오.
- 동일한 커밋에서 관련성이 없는 파일에 대한 외관상의 변화를 피하십시오. 노이즈로 인해 검토 시간이 오래 걸릴 수 있습니다.
- master 브랜치 대신 [feature branch] [git-feature-branch]를 사용하십시오.
- 소규모 PR의 경우 ** rebase workflow **를 사용하십시오.
  - 검토 의견을 언급 한 후 rebase하고 강제로 푸시하는 것이 좋습니다.
- 크고 위험도가 높은 당겨받기 요청에는 ** merge workflow **를 사용하십시오.

  - 충돌이 있거나 master가 변경 사항을 도입할 때 'master' 를 PRs에 병합하십시오.
  - `ri` git 별칭 사용 :
    ```
    [alias]
    ri = "!sh -c 't=\"${1:-master}\"; s=\"${2:-HEAD}\"; mb=\"$(git merge-base \"$t\" \"$s\")\"; if test \"x$mb\" = x ; then o=\"$t\"; else lm=\"$(git log -n1 --merges \"$t..$s\" --pretty=%H)\"; if test \"x$lm\" = x ; then o=\"$mb\"; else o=\"$lm\"; fi; fi; test $# -gt 0 && shift; test $# -gt 0 && shift; git rebase --interactive \"$o\" \"$@\"'"
    ```
    이렇게하면 불필요한 rebase를 피할 수 있지만 관련된 커밋, 별도의 monolithic 커밋 등을 결합 할 수 있습니다.
  - 병합 커밋 이전의 커밋은 편집하지 마십시오.
- squash / fixup 중에 각 pick / edit / reword 사이에서 'exec make -C unittest'를 사용하십시오.

### 단계: WIP, RFC, RDY
 
Pull requests는 세가지 단계를 가집니다: [WIP] (Work In Progress), [RFC] (Request For Comment) and [RDY] (Ready).

- 
- Nvim 개발자는 ':help dev-help'를 읽어야 합니다.
- 외부 UI 개발자는 ':help dev-ui'를 읽어야 합니다.

문제 보고
------------------

- [** FAQ **] [wiki-faq]를 확인하십시오.
- [기존 문제][github-issues]검색 (닫음 포함)
- Neovim을 최신 버전으로 업데이트하여 문제가 지속되는지 확인하십시오.
- 플러그인 관리자를 사용하는 경우 플러그인을 주석으로 처리 한 다음 하나씩 다시 추가하여 문제의 원인을 좁힙니다.
- 스택 추적을 포함하는 오류 보고서는 10배 더 가치가 있습니다.
- 퇴행의 원인에 대해 [git-bisect]을 [Bisecting] 하면 종종 즉각적인 수정이 이루어집니다.
 
당겨받기 요청 ("PRs")
---------------------

- 중복 작업을 피하려면 가능한 한 빨리 '[WIP]' pull 요청을 만드십시오.
- 동일한 커밋에서 관련성이 없는 파일에 대한 외관상의 변화를 피하십시오. 노이즈로 인해 검토 시간이 오래 걸릴 수 있습니다.
- master 브랜치 대신 [feature branch] [git-feature-branch]를 사용하십시오.
- 소규모 PR의 경우 ** rebase workflow **를 사용하십시오.
  - 검토 의견을 언급 한 후 rebase하고 강제로 푸시하는 것이 좋습니다.
- 크고 위험도가 높은 당겨받기 요청에는 ** merge workflow **를 사용하십시오.

  - 충돌이 있거나 master가 변경 사항을 도입할 때 'master' 를 PRs에 병합하십시오.
  - `ri` git 별칭 사용 :
    ```
    [alias]
    ri = "!sh -c 't=\"${1:-master}\"; s=\"${2:-HEAD}\"; mb=\"$(git merge-base \"$t\" \"$s\")\"; if test \"x$mb\" = x ; then o=\"$t\"; else lm=\"$(git log -n1 --merges \"$t..$s\" --pretty=%H)\"; if test \"x$lm\" = x ; then o=\"$mb\"; else o=\"$lm\"; fi; fi; test $# -gt 0 && shift; test $# -gt 0 && shift; git rebase --interactive \"$o\" \"$@\"'"
    ```
    이렇게하면 불필요한 rebase를 피할 수 있지만 관련된 커밋, 별도의 monolithic 커밋 등을 결합 할 수 있습니다.
  - 병합 커밋 이전의 커밋은 편집하지 마십시오.
- squash / fixup 중에 각 pick / edit / reword 사이에서 'exec make -C unittest'를 사용하십시오.

### 단계: WIP, RFC, RDY
 
Pull requests는 세가지 단계를 가집니다: [WIP] (Work In Progress), [RFC] (Request For Comment) and [RDY] (Ready).

- Untagged PR은[RFC]로 간주됩니다.
- 진행중인 작업이 피드백을 요구하지 않고 유동적이라면 [WIP]을 PR 제목 앞에 추가하십시오.
- PR을 마치고 병합을 기다리는 중일 때 PR 제목 앞에 [RDY]를 앞에 붙이십시오.

예를들어, 일반적인 작업의 흐름은 다음과 같습니다 :

1. 피드백 준비가 되지 않은 [WIP]PR 문은 다른 사람들에게 자신이 하는 일을 알리는 결과만 도출합니다.
2. PR이 검토 될 준비가 되면 제목의 [WIP]를 [RFC]로 대체하십시오.   검토 중 발생하는 문제를 해결하기 위해 커밋을 수정할 수 있습니다
3. PR이 병합 될 준비가 되면, 작업을 적절하게 rebase / squash 한 다음 제목에있는 [[RFC]를[RDY]`로 대체하십시오.

### Commit messages

Follow [commit message hygiene][hygiene] to *make reviews easier* and to make
the VCS/git logs more valuable.

- Try to keep the first line under 72 characters.
- **Prefix the commit subject with a _scope_:** `doc:`, `test:`, `foo.c:`,
  `runtime:`, ...
    - For commits that contain only style/lint changes, a single-word subject
      line is preferred: `style` or `lint`.
- A blank line must separate the subject from the description.
- Use the _imperative voice_: "Fix bug" rather than "Fixed bug" or "Fixes bug."

### Automated builds (CI)

Each pull request must pass the automated builds ([travis CI] and [quickbuild]).

- CI builds are compiled with [`-Werror`][gcc-warnings], so if your PR
  introduces any compiler warnings, the build will fail.
- If any tests fail, the build will fail.
  See [Building Neovim#running-tests][wiki-run-tests] to run tests locally.
  Passing locally doesn't guarantee passing the CI build, because of the
  different compilers and platforms tested against.
- CI runs [ASan] and other analyzers. To run valgrind locally:
  `VALGRIND=1 make test`
- The `lint` build ([#3174][3174]) checks modified lines _and their immediate
  neighbors_. This is to encourage incrementally updating the legacy style to
  meet our style guidelines.
    - A single word (`lint` or `style`) is sufficient as the subject line of
      a commit that contains only style changes.
- [How to investigate QuickBuild failures](https://github.com/neovim/neovim/pull/4718#issuecomment-217631350)

QuickBuild uses this invocation:

    mkdir -p build/${params.get("buildType")} \
    && cd build/${params.get("buildType")} \
    && cmake -G "Unix Makefiles" -DBUSTED_OUTPUT_TYPE=TAP -DCMAKE_BUILD_TYPE=${params.get("buildType")}
    -DTRAVIS_CI_BUILD=ON ../.. && ${node.getAttribute("make", "make")}
    VERBOSE=1 nvim unittest-prereqs functionaltest-prereqs


### Coverity

[Coverity](https://scan.coverity.com/projects/neovim-neovim) runs against the
master build. To view the defects, just request access; you will be approved.

Use this commit-message format for coverity fixes:

    coverity/<id>: <description of what fixed the defect>

where `<id>` is the Coverity ID (CID). For example see [#804](https://github.com/neovim/neovim/pull/804).

### PVS-Studio

View the [PVS analysis report](https://neovim.io/doc/reports/pvs/) to see bugs
found by [PVS Studio](https://www.viva64.com/en/pvs-studio/).
You can run `scripts/pvscheck.sh` locally to run PVS on your machine.

Reviewing
---------

To help review pull requests, start with [this checklist][review-checklist].

Reviewing can be done on GitHub, but you may find it easier to do locally.
Using [`hub`][hub], you can create a new branch with the contents of a pull
request, e.g. [#1820][1820]:

    hub checkout https://github.com/neovim/neovim/pull/1820

Use [`git log -p master..FETCH_HEAD`][git-history-filtering] to list all
commits in the feature branch which aren't in the `master` branch; `-p`
shows each commit's diff. To show the whole surrounding function of a change
as context, use the `-W` argument as well.

[gcc-warnings]: https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html
[git-bisect]: http://git-scm.com/book/tr/v2/Git-Tools-Debugging-with-Git
[git-feature-branch]: https://www.atlassian.com/git/tutorials/comparing-workflows
[git-history-filtering]: https://www.atlassian.com/git/tutorials/git-log/filtering-the-commit-history
[git-history-rewriting]: http://git-scm.com/book/en/v2/Git-Tools-Rewriting-History
[git-rebasing]: http://git-scm.com/book/en/v2/Git-Branching-Rebasing
[github-issues]: https://github.com/neovim/neovim/issues
[1820]: https://github.com/neovim/neovim/pull/1820
[hub]: https://hub.github.com/
[hygiene]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
[style-guide]: http://neovim.io/develop/style-guide.xml
[ASan]: http://clang.llvm.org/docs/AddressSanitizer.html
[wiki-run-tests]: https://github.com/neovim/neovim/wiki/Building-Neovim#running-tests
[wiki-faq]: https://github.com/neovim/neovim/wiki/FAQ
[review-checklist]: https://github.com/neovim/neovim/wiki/Code-review-checklist
[3174]: https://github.com/neovim/neovim/issues/3174
[travis CI]: https://travis-ci.org/neovim/neovim
[quickbuild]: http://neovim-qb.szakmeister.net/dashboard
[Vim patch]: https://github.com/neovim/neovim/wiki/Merging-patches-from-upstream-Vim
[clang-scan]: https://neovim.io/doc/reports/clang/
[complexity:low]: https://github.com/neovim/neovim/issues?q=is%3Aopen+is%3Aissue+label%3Acomplexity%3Alow
