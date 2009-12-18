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
      if c[last_bit].is_a?(Array) 
        if d.is_a?(Array)
          c[last_bit] = c[last_bit] + d
        else
          c[last_bit] << d
        end
      else
        c[last_bit] = d
      end
    end

    def clear(path = nil)
      return if @data.nil?
      return @data.clear(path)
      
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
      c[last_bit] = { }
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
