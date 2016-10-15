defmodule Translator do
  
  defmacro __using__(_options) do
    quote do
      Module.register_attribute __MODULE__, :locales, accumulate: true, persist: false

      import unquote(__MODULE__), only: [locale: 2]
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    compile(Module.get_attrubute(env.module, :locales))
  end

  defmacro locale(name, mappings) do
    quote bind_quoted: [name: name, mappings: mappings] do
      @locales {name, mappings}
    end
  end

  def compile(translations) do
    # TBD: Return AST for all translation function definitions
  end
end
