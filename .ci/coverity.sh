. "$CI_SCRIPTS/common.sh"

# temporarily disable error checking, the coverity script exits with
# status code 1 whenever it (1) fails OR (2) is not on the correct
# branch.
set +e
curl -s https://scan.coverity.com/scripts/travisci_build_coverity_scan.sh |
COVERITY_SCAN_PROJECT_NAME="neovim/neovim" \
	COVERITY_SCAN_NOTIFICATION_EMAIL="coverity@aktau.be" \
	COVERITY_SCAN_BRANCH_PATTERN="coverity-scan" \
	COVERITY_SCAN_BUILD_COMMAND_PREPEND="$MAKE_CMD deps" \
	COVERITY_SCAN_BUILD_COMMAND="$MAKE_CMD nvim" \
	bash
set -e

exit 0
