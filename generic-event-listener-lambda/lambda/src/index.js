exports.handler = async (event) => {
  console.log("Starting")
  const batchItemFailures = [];

  try {
    for (const record of event.Records) {
      const messageId = record.messageId;

      console.log("Processing messageId=" + messageId);

      try {
        const body = JSON.parse(record.body);

        const {
          companyId,
          eventType,
          occurredAt,
        } = body;

        if (!eventType || !occurredAt) {
          throw new Error('Missing required fields');
        }

        console.log(body);

      } catch (err) {
        console.error(`Failed processing message ${messageId}`, err);

        // Tell Lambda/SQS to retry only this message
        batchItemFailures.push({
          itemIdentifier: messageId,
        });
      }
    }

  } catch (outerErr) {
    console.error('Unexpected batch-level failure', outerErr);

    // If something catastrophic happens, fail entire batch
    return {
      batchItemFailures: event.Records.map(r => ({
        itemIdentifier: r.messageId,
      })),
    };
  }

  return { batchItemFailures };
};
