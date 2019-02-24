module BcastFileTransfer
  # Holds the result of a single "transfer" operation
  class S3UploadResult
    attr_reader :file, :upload_status

    def initialize(file, upload_status)
      @file = file
      @upload_status = upload_status
    end

    def success?
      @upload_status
    end
  end
end
