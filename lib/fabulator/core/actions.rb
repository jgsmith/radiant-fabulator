require 'fabulator/action_lib'
require 'fabulator/core/actions/choose'
require 'fabulator/core/actions/for_each'
require 'fabulator/core/actions/variables'

module Fabulator
  module Core
  module Actions
  class Lib
    include ActionLib
    register_namespace FAB_NS

    action 'choose', Choose
    action 'for-each', ForEach
    action 'value-of', ValueOf
    action 'value', Value
    action 'while', While
    action 'considering', Considering
    action 'variable', Variable
    action 'if', If

    ###
    ### Numeric functions
    ###

    function 'abs' do |args|
      res = [ ]
      args.each do |arg|
        arg.each do |i|
          res << i.value.abs
        end
      end
      res
    end

    function 'ceiling' do |args|
      res = [ ]
      args.each do |arg|
        arg.each do |i|
          res << i.value.ceil
        end
      end
      res
    end

    function 'floor' do |args|
      res = [ ]
      args.each do |arg|
        arg.each do |i|
          res << i.value.floor
        end
      end
      res
    end

    function 'sum' do |args|
      res = 0
      return args[1] if args.first.empty? && args.size > 1

      args.first.each do |a|
        res = res + a.value.to_f
      end
      if res.floor == res
        [ res.to_i ]
      else
        [ res ]
      end
    end

    function 'avg' do |args|
      res = 0.0
      n = 0.0
      args.first.each do |a|
        res = res + a.value.to_f
        n = n + 1.0
      end
      res = res / n if n > 0
      if res.floor == res
        [ res.to_i ]
      else
        [ res ]
      end
    end

    function 'max' do |args|
      res = nil
      args[0].each do |a|
        res = a.value.to_f if res.nil? || a.value.to_f > res
      end

      if res.floor == res
        [res.to_i]
      else
        [res]
      end
    end

    function 'min' do |args|
      res = nil
      args[0].each do |a|
        res = a.value.to_f if res.nil? || a.value.to_f < res
      end

      if res.floor == res
        [res.to_i]
      else
        [res]
      end
    end

    function 'histogram' do |args|
      acc = { }
      args[0].each do |a|
        acc[a.value.to_s] ||= 0
        acc[a.value.to_s] = acc[a.value.to_s] + 1
      end
      acc
    end

    ###
    ### String functions
    ###

    #
    # f:concat(node-set) => node
    #
    function 'concat' do |args|
      return '' if args.empty? || args[0].empty?
      [ args[0].collect{ |a| a.value.to_s}.join('') ]
    end

    #
    # f:string-join(node-set, joiner) => node
    #
    function 'string-join' do |args|
      joiner = args[1].first.value.to_s
      [ args[0].collect{|a| a.value.to_s }.join(joiner) ]
    end

    #
    # f:substring(node-set, begin)
    # f:substring(node-set, begin, length)
    #
    function 'substring' do |args|
      first = args[1].first.value
      if args.size == 3
        last = args[2].first.value
        return [ args[0].collect{ |src| src.value.to_s.substr(first, last) } ]
      else
        return [ args[0].collect{ |src| src.value.to_s.substr(first) } ]
      end
    end

    #
    # f:string-length(node-list) => node-list
    #
    function 'string-length' do |args|
      args[0].collect{ |a| a.value.to_s.length }
    end

    function 'normalize-space' do |args|
      args[0].collect{ |a| a.value.to_s.gsub(/^\s+/, '').gsub(/\s+$/,'').gsub(/\s+/, ' ') }
    end

    function 'upper-case' do |args|
      args[0].collect{ |a| a.value.to_s.upcase }
    end

    function 'lower-case' do |args|
      args[0].collect{ |a| a.value.to_s.downcase }
    end

    function 'split' do |args|
      div = args[1].first.value
      args[0].collect{ |a| a.value.split(div) }
    end

    function 'contains' do |args|
      tgt = (args[1].first.value.to_s rescue '')
      return args[0].collect{ |a| (a.value.to_s.include?(tgt) rescue false) }
    end

    function 'starts-with' do |args|
      tgt = (args[1].first.value.to_s rescue '')
      tgt_len = tgt.size - 1
      return args[0].collect{ |a| (a.value.to_s[0,tgt_len] == tgt rescue false) }
    end

    function 'ends-with' do |args|
      tgt = (args[1].first.value.to_s rescue '').reverse
      tgt_len = tgt.size
      return args[0].collect{ |a| (a.value.to_s[-tgt_len,-1] == tgt rescue false) }
    end

    function 'substring-before' do |args|
      tgt = (args[1].first.value.to_s rescue '')
      return [ '' ] if tgt == ''

      return args[0].collect{ |a| (a.value.to_s.split(tgt,2))[0] }
    end

    function 'substring-after' do |args|
      tgt = (args[1].first.value.to_s rescue '')

      return args[0].collect{ |a| a.value.to_s } if tgt == ''

      return args[0].collect{ |a| a.value.to_s.include?(tgt) ? (a.value.to_s.split(tgt))[-1] : "" }
    end
    

    ###
    ### Regexes
    ###

    function 'matches' do |args|
    end

    function 'replace' do |args|
    end

    function 'tokenize' do |args|
    end

    ###
    ### Boolean
    ###

    function 'true' do |args|
      return [ true ]
    end

    function 'false' do |args|
      return [ false ]
    end

    function 'not' do |args|
      return args[0].collect{ |a| !a.value }
    end

    ###
    ### data node functions
    ###

    function 'name' do |args|
      return args[0].collect{|a| a.name || '' }
    end

    function 'root' do |args|
      return args[0].collect{|a| a.root }
    end

    function 'lang' do |args|
      # we want to track language for rdf purposes?
    end

    ###
    ### Sequences
    ###

    function 'empty' do |args|
      return [ args[0].empty? ]
    end

    function 'exists' do |args|
      return [ !args[0].empty? ]
    end

    function 'reverse' do |args|
      return args[0].reverse
    end

    function 'zero-or-one' do |args|
      return [ args[0].size <= 1 ]
    end

    function 'one-or-more' do |args|
      return [ args[0].size >= 1 ]
    end

    function 'zero-or-one' do |args|
      return [ args[0].size == 1 ]
    end

    function 'count' do |args|
      return [ args[0].size ]
    end

    ###
    ### Context
    ###

    function 'position' do |args|
    end

    function 'last' do |args|
    end
  end
  end
  end
end
