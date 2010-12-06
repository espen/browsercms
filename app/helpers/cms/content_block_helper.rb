module Cms
  module ContentBlockHelper
    def pick_methods_from_objects(methods, objects)
      results = objects.map do |object|
        result = methods.map do |method|
          method = method.to_s
          [method.gsub(".", "_"), method.split(".").inject(object) { |memo, method| memo.send(method) }]
        end
        Hash[*result.flatten]
      end
    end
  end
end

