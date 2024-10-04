function labeledEvent(data) {
  return data.event === "labeled" && data.label.name === "needs:response";
}

// Externalized constants for flexibility
const numberOfDaysLimit = 30;
const labelName = "needs:response";
const closeMessage = `This has been closed since a request for information has not been answered for ${numberOfDaysLimit} days. It can be reopened when the requested information is provided.`;

module.exports = async ({ github, context }) => {
  const { owner, repo } = context.repo; // Destructure for cleaner code

  try {
    // Fetch all issues with the label 'needs:response'
    const issues = await github.rest.issues.listForRepo({
      owner,
      repo,
      labels: labelName,
    });

    const issueNumbers = issues.data.map(issue => issue.number);

    // Process each issue concurrently using Promise.all for performance
    await Promise.all(
      issueNumbers.map(async (issueNumber) => {
        try {
          // Get timeline events for each issue, filter by labeled events
          const events = await github.paginate(
            github.rest.issues.listEventsForTimeline,
            { owner, repo, issue_number: issueNumber },
            (response) => response.data.filter(labeledEvent)
          );

          if (events.length === 0) {
            console.log(`No matching events found for issue #${issueNumber}`);
            return; // Skip this issue if no relevant events are found
          }

          // Get the latest relevant labeled event
          const latestResponseLabel = events[events.length - 1];
          const createdAt = new Date(latestResponseLabel.created_at);
          const now = new Date();

          // Calculate the difference in days using a more readable approach
          const diffDays = Math.floor((now - createdAt) / (1000 * 60 * 60 * 24));

          if (diffDays > numberOfDaysLimit) {
            // Close the issue and comment with a closure message
            await github.rest.issues.update({
              owner,
              repo,
              issue_number: issueNumber,
              state: "closed",
              state_reason: "not_planned",
            });

            await github.rest.issues.createComment({
              owner,
              repo,
              issue_number: issueNumber,
              body: closeMessage,
            });

            console.log(`Issue #${issueNumber} closed and commented.`);
          }
        } catch (error) {
          console.error(`Failed to process issue #${issueNumber}:`, error.message);
        }
      })
    );
  } catch (error) {
    console.error('Error fetching issues:', error.message);
  }
};
