module Fabulator
  class Context
    attr_accessor :data, :state

    def initialize
      @state = 'start'
      @data = nil
    end

    def empty?
      @state = 'start' if @state.nil?
      (@data.nil? || @data.empty?) && @state == 'start'
    end

    def merge!(d, path=nil)
      return if @data.nil?
      return @data.merge_data(d,path)
    end

    def clear(path = nil)
      return if @data.nil?
      return @data.clear(path)
    end

    def context
      { :state => @state, :data => @data }
    end

    def context=(c)
      @state = c[:state]
      @data  = c[:data]
    end

    def get(p = nil)
      return if @data.nil?
      return @data.get(p)
    end
  end
end
