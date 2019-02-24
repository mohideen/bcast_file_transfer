module BcastFileTransfer
  # Encapsulates results of running script operations
  class ScriptResult
    attr_reader :config_hash, :destination_results, :move_results, :prune_results
    def initialize(config_hash, destination_results, move_results, prune_results)
      @config_hash = config_hash
      @destination_results = destination_results
      @move_results = move_results
      @prune_results = prune_results
    end

    def success?
      false if @destination_results.nil?
      @destination_results.map(&:success?).all?
    end
  end
end
