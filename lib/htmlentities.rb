require 'htmlentities'

class HTMLEntities
  class Encoder
    def basic_entity_regexp
      # Don't encode <, >, ', " and &.
      # They are part of the HTML markup and don't need to be displayed as literal characters
      # https://github.com/threedaymonk/htmlentities/blob/049ec3b63c2fcc86fc58ca6e65310482be5a0891/lib/htmlentities/encoder.rb#L41
      @basic_entity_regexp ||= /["]/
    end
  end
end
