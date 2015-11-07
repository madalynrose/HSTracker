class LogReaderManager

  TimeoutRead = 0.5

  def start
    log :reader_manager, starting: true
    init_readers

    @starting_point = get_starting_point
    start_log_readers
  end

  def init_readers
    mp init_readers: true
    @power = LogReader.new('Power',
                           self,
                           starts_filters: ['GameState.'],
                           contains_filters: ['Begin Spectating', 'Start Spectator', 'End Spectator'])
    @bob = LogReader.new('Bob', self)

    @readers = [@power, @bob]
    %w(Rachelle Asset Arena).each do |name|
      @readers << LogReader.new(name, self)
    end

    @readers << LogReader.new('Zone', self, contains_filters: ['zone from'])
  end

  def get_starting_point
    power_entry = @power.find_entry_point('GameState.DebugPrintPower() - CREATE_GAME')
    bob_entry = @bob.find_entry_point('legend rank')
    mp power_entry: power_entry,
       bob_entry: bob_entry,
       diff: power_entry > bob_entry
    power_entry > bob_entry ? power_entry : bob_entry
  end

  def start_log_readers
    log :reader_manager, starting_readers: @starting_point

    @readers.each do |reader|
      reader.start(@starting_point)
    end
  end

  def stop
    log :reader_manager, stopping: true

    @readers.each do |reader|
      reader.stop
    end
    @readers = []
  end

  def restart
    log :reader_manager, restarting: true
    @readers ||= []
    stop
    start
  end

  def process_new_line(line)
    Dispatch::Queue.main.async do
      case line.namespace
        when 'Power'
          PowerGameStateHandler.handle(line.line)
        when 'Zone'
          ZoneHandler.handle(line.line)
        when 'Asset'
          AssetHandler.handle(line.line)
        when 'Bob'
          BobHandler.handle(line.line)
        when 'Rachelle'
          RachelleHandler.handle(line.line)
        when 'Arena'
          ArenaHandler.handle(line.line)
      end
    end
  end

end
