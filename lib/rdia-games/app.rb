#require 'wads'
require_relative '../../../ruby-wads/lib/wads'
require_relative 'widgets'

include Wads

module RdiaGames
    #
    # The WadsApp class provides a simple starting point to quickly build a native
    # Ruby application using Gosu as an underlying library. It provides all the necessary
    # hooks to get started. All you need to do is supply the parent Wads widget using
    # the set_display(widget) method. See one of the Wads samples for example usage.
    #
    class RdiaGame < WadsApp
        def initialize(width, height, caption, widget)
            super
        end 
    end 
end