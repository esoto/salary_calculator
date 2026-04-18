module PaperTrailHelpers
  # Enables PaperTrail for the duration of the block, then restores prior state.
  # Mirrors the helper provided by paper_trail/frameworks/rspec but avoids
  # disabling versioning globally in the test suite.
  def with_versioning
    original = PaperTrail.enabled?
    PaperTrail.enabled = true
    yield
  ensure
    PaperTrail.enabled = original
  end
end

RSpec.configure do |config|
  config.include PaperTrailHelpers
end
