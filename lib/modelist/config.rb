# If you use Modelist in an application, you can specify:
#   Modelist.quiet = true
# to limit output.
module Modelist
  OPTIONS = [:quiet]

  class << self
    OPTIONS.each{|o|attr_accessor o; define_method("#{o}?".to_sym){!!send("#{o}")}}
    def configure(&blk); class_eval(&blk); end
  end
end
