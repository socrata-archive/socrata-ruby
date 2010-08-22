class String
   def underscore
     self.to_s.gsub(/::/, '/').
       gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
       gsub(/([a-z\d])([A-Z])/,'\1_\2').
       tr("-", "_").
       downcase
   end

   def camelize(leading_caps = true)
     s = self.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
     s = leading_caps ? s : s[0...1].downcase + s[1..-1]
   end
end

class Util
  def self.symbolize_keys(obj)
    case obj
    when Array
      obj.inject([]){|res, val|
        res << case val
        when Hash, Array
          symbolize_keys(val)
        else
          val
        end
        res
      }
    when Hash
      obj.inject({}){|res, (key, val)|
        nkey = case key
        when String
          key.to_sym
        else
          key
        end
        nval = case val
        when Hash, Array
          symbolize_keys(val)
        else
          val
        end
        res[nkey] = nval
        res
      }
    else
      obj
    end
  end

  def self.camelize_keys(obj)
    case obj
    when Array
      obj.inject([]){|res, val|
        res << case val
        when Hash, Array
          camelize_keys(val)
        else
          val
        end
        res
      }
    when Hash
      obj.inject({}){|res, (key, val)|
        nkey = case key
        when String
          key.camelize
        when Symbol 
          key.to_s.camelize(false)
        else
          key
        end
        nval = case val
        when Hash, Array
          camelize_keys(val)
        else
          val
        end
        res[nkey] = nval
        res
      }
    else
      obj
    end
  end
end

__END__

class Hash
  def recursive_camelize(leading_caps = false)
    inject({}) do |acc, (k,v)|
      k =  k.to_s.camelize(leading_caps)

      case v
      when Hash
        v = v.recursive_camelize
      when Array
        v.inject([]) do |res, val|
          res << case val
          when Hash
            val.recursive_camelize(leading_caps)
          else
            val
          end
          res
        end
      end
      acc[k] = v
      acc
    end
  end
end
__END__

def symbolize_keys
    inject({}) do |acc, (k,v)|
      key = String === k ? k.to_sym : k
      value = Hash === v ? v.symbolize_keys : v
      acc[key] = value
      acc
    end
  end

class Hash
  def recursive_symbolize_keys!
    symbolize_keys!
    # symbolize each hash in .values
    values.each{|h| h.recursive_symbolize_keys! if h.is_a?(Hash) }
    # symbolize each hash inside an array in .values
    values.select{|v| v.is_a?(Array) }.flatten.each{|h| h.recursive_symbolize_keys! if h.is_a?(Hash) }
    self
  end
end

 def camelize(lower_case_and_underscored_word, first_letter_in_uppercase = true)
180:       if first_letter_in_uppercase
181:         lower_case_and_underscored_word.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
182:       else
183:         lower_case_and_underscored_word.first.downcase + camelize(lower_case_and_underscored_word)[1..-1]
184:       end

