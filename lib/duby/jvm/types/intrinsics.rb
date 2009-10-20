require 'bitescript'

class BiteScript::MethodBuilder
  def op_to_bool
    done_label = label
    true_label = label

    yield(true_label)
    iconst_0
    goto(done_label)
    true_label.set!
    iconst_1
    done_label.set!
  end
end

module Duby::JVM::Types
  class Type
    def load(builder, index)
      builder.send "#{prefix}load", index
    end
    
    def store(builder, index)
      builder.send "#{prefix}store", index
    end
    
    def return(builder)
      builder.send "#{prefix}return"
    end
    
    def init_value(builder)
      builder.aconst_null
    end
    
    def intrinsics
      @intrinsics ||= begin
        @intrinsics = Hash.new {|h, k| h[k] = {}}
        add_intrinsics
        @intrinsics
      end
    end
    
    def add_method(name, args, method_or_type=nil, &block)
      if block_given?
        method_or_type = Intrinsic.new(self, name, args,
                                       method_or_type, &block)
      end
      intrinsics[name][args] = method_or_type
    end

    def declared_intrinsics
      methods = []
      intrinsics.each do |name, group|
        group.each do |args, method|
          methods << method
        end
      end
      methods
    end

    def add_intrinsics
      add_method('nil?', [], Boolean) do |compiler, call, expression|
        if expression
          call.target.compile(compiler, true)
          compiler.method.op_to_bool do |target|
            compiler.method.ifnull(target)
          end
        end
      end
      
      add_method('==', [Object], Boolean) do |compiler, call, expression|
        # Should this call Object.equals for consistency with Ruby?
        if expression
          call.target.compile(compiler, true)
          call.parameters[0].compile(compiler, true)
          compiler.method.op_to_bool do |target|
            compiler.method.if_acmpeq(target)
          end
        end
      end
      
      add_method('!=', [Object], Boolean) do |compiler, call, expression|
        # Should this call Object.equals for consistency with Ruby?
        if expression
          call.target.compile(compiler, true)
          call.parameters[0].compile(compiler, true)
          compiler.method.op_to_bool do |target|
            compiler.method.if_acmpne(target)
          end
        end
      end
    end
  end
  
  class ArrayType
    def add_intrinsics
      super
      add_method(
          '[]', [Int], component_type) do |compiler, call, expression|
        if expression
          call.target.compile(compiler, true)
          call.parameters[0].compile(compiler, true)
          if component_type.primitive?
            compiler.method.send "#{name[0,1]}aload"
          else
            compiler.method.aaload
          end
        end
      end

      add_method('[]=',
                 [Int, component_type],
                 component_type) do |compiler, call, expression| 
        call.target.compile(compiler, true)
        convert_args(compiler, call.parameters, [Int, component_type])
        if component_type.primitive?
          compiler.method.send "#{name[0,1]}astore"
        else
          compiler.method.aastore
        end
        if expression
          call.parameters[1].compile(compiler, true)
        end
      end
      
      add_method('length', [], Int) do |compiler, call, expression|
        call.target.compile(compiler, true)
        compiler.method.arraylength              
      end
    end
  end
  
  class StringType < Type
    def add_intrinsics
      super
      add_method('+', [String], String) do |compiler, call, expression| 
        if expression
          java_method('concat', String).call(compiler, call, expression)
        end
      end
    end
  end
  
  class PrimitiveType
    # Primitives define their own intrinsics instead of getting the Object ones.
    def add_intrinsics
    end
  end
end