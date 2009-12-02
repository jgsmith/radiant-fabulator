module Fabulator
  class Context
    attr_accessor :data, :state

    def initialize
      @state = 'start'
      @data = { }
    end

    def empty?
      @data = { } if @data.nil?
      @state = 'start' if @state.nil?
      @data.empty? && @state == 'start'
    end

    def merge!(d, path=[])
      bits = [] + path
      last_bit = bits.pop
      c = @data
      bits.each do |b|
        if c.is_a?(Array)
          c[b.to_i] = { } if c[b.to_i].nil?
          c = c[b.to_i]
        else
          c[b] = { } if c[b].nil?
          c = c[b]
        end
      end
      c[last_bit] = d
    end

    def context
      { :state => @state, :data => @data }
    end

    def context=(c)
      @state = c[:state]
      @data  = c[:data]
    end

    def get(p = [])
      bits = [ ] +  p
      last_bit = bits.pop
      c = @data
      bits.each do |b|
        if c.is_a?(Array)
          c[b.to_i] = { } if c[b.to_i].nil?
          c = c[b.to_i]
        else
          c[b] = { } if c[b].nil?
          c = c[b]
        end
      end
      c[last_bit]
    end
  end
end
