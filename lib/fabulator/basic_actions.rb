require 'fabulator/action_lib'
require 'fabulator/basic_actions/choose'
require 'fabulator/basic_actions/for_each'
require 'fabulator/basic_actions/variables'

module Fabulator
  module BasicActions
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

    ###
    ### String functions
    ###

    function 'concat' do |args|
      return '' if args.empty? || args[0].empty?
      [ args[0].collect{ |a| a.value.to_s}.join('') ]
    end

    function 'string-join' do |args|
      joiner = args[1].first.value
      [ args[0].collect{|a| a.value.to_s }.join(joiner) ]
    end

    function 'substring' do |args|
      src = args[0].first.value
      first = args[1].first.value
      if args.size == 3
        last = args[2].first.value
        return [ src.substr(first, last) ]
      else
        return [ src.substr(first) ]
      end
    end

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
  end
  end
end
