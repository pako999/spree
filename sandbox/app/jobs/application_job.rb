class ApplicationJob < ActiveJob::Base
  # Retry transient database deadlocks up to 3 times with exponential back-off.
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 3

  # Discard jobs whose serialized records no longer exist — avoids infinite
  # retry loops for deleted variants, blobs, orders, etc.
  discard_on ActiveJob::DeserializationError

  # ActiveStorage transform/analyze jobs fail permanently when the source blob
  # has been deleted (e.g. after re-importing products). Discard instead of
  # filling the failed_executions table (was 33k+ rows clogging the queue).
  discard_on ActiveStorage::FileNotFoundError
end
