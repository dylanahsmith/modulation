require 'minitest/autorun'
require_relative '../lib/modulation.rb'
Modulation.full_backtrace!

MODULES_DIR = File.join(File.dirname(__FILE__), 'modules')
RELOADED_FN = File.join(MODULES_DIR, 'reloaded.rb')

class FileHandlingTest < Minitest::Test
  def setup
    Modulation.reset!
  end
  
  def teardown
    Modulation.reset!
  end

  def test_that_import_raises_on_file_not_found
    assert_raises(Exception) {import('./not_found')}
  end


  def test_that_import_takes_filename_without_rb_extension
    a1 = import('./modules/a')
    a2 = import('./modules/a.rb')

    assert_same(a1, a2)
  end

  def test_that_import_loads_the_same_file_only_once
    $inc = 0
    import('./modules/inc')
    import('./modules/inc')

    assert_equal(1, $inc)
  end

  def test_that_filenames_are_always_relative
    $inc = 0
    import('./modules/b1')
    assert_equal(1, $inc)

    fn_b1 =   File.expand_path('modules/b1.rb', File.dirname(__FILE__))
    fn_b2 =   File.expand_path('modules/b/b2.rb', File.dirname(__FILE__))
    fn_inc =  File.expand_path('modules/inc.rb', File.dirname(__FILE__))
    
    assert_equal([fn_b2, fn_b1, fn_inc], Modulation.loaded_modules.keys.sort)
  end
end

class ExportTest < Minitest::Test
  def setup
    @a = import('./modules/a')
  end

  def teardown
    Modulation.reset!
  end

  def test_that_non_exported_consts_are_not_accessible
    assert_raises(NameError) {@a::PrivateClass}
  end

  def test_that_non_exported_consts_are_saved_in_module_info
    assert_equal(@a.__module_info[:private_constants], [:PrivateClass])
  end

  def test_that_exported_consts_are_accessible
    assert_equal 42, @a::ExportedConstant
  end

  def test_that_non_exported_methods_are_not_accessible
    assert_raises(NameError) {@a.private_method}
  end

  def test_that_exported_methods_are_accessible
    assert_equal "private", @a.exported_method
  end

  def test_that_private_class_is_accessible_to_module
    assert_kind_of Class, @a.access_private_class
  end
end

class ExposeTest < MiniTest::Test
  def setup
    @a = import('./modules/a').__expose!
  end

  def teardown
    Modulation.reset!
  end

  def test_that_expose_exposes_private_methods
    assert_equal(@a.private_method, 'private')
    assert_equal(@a::PrivateClass.class, Class)
  end
end

class ExportDefaultTest < MiniTest::Test
  def teardown
    FileUtils.rm(RELOADED_FN)
    Modulation.reset!
  end

  def write_template(code)
    Modulation.reset!
    File.open(RELOADED_FN, 'w+') {|f| f << code}
  end

  def test_default_export_types
    write_template("export_default :abc")
    assert_raises(TypeError) {import('./modules/reloaded')}
    
    write_template("export_default 42")
    assert_raises(TypeError) {import('./modules/reloaded')}

    write_template("export_default false")
    assert_raises(TypeError) {import('./modules/reloaded')}

    write_template("export_default 'abc'")
    assert_equal('abc', import('./modules/reloaded'))
  end
end

class ExtendFrom1Test < MiniTest::Test
  def setup
    @m = Module.new
    @m.extend_from('modules/ext')
  end

  def teardown
    Modulation.reset!
  end

  def test_that_extend_from_extends_a_module
    assert_respond_to(@m, :a)
    assert_respond_to(@m, :b)
    assert_raises(NameError) {@m.c}

    assert_equal :a, @m.a
    assert_equal :b, @m.b
  end
end

class ExtendFrom2Test < MiniTest::Test
  def setup
    @m = Module.new
    @m.extend_from('./modules/extend_from1')
    @m.extend_from('./modules/extend_from2')
  end
  
  def teardown
    Modulation.reset!
  end

  def test_that_extend_from_doesnt_mix_private_methods
    assert_equal(1, @m.method1)
    assert_equal(2, @m.method2)
  end

  def test_that_extend_from_adds_constants
    assert_equal(:bar, @m::FOO)
  end
end

class IncludeFromTest < MiniTest::Test
  def setup
    @c = Class.new
    @c.include_from('modules/ext')    
  end

  def teardown
    Modulation.reset!
  end

  def test_that_include_from_adds_instance_methods_to_class
    @o = @c.new
    assert_respond_to(@o, :a)
    assert_respond_to(@o, :b)
    assert_raises(NameError) {@o.c}

    assert_equal :a, @o.a
    assert_equal :b, @o.b
  end

  def test_that_include_from_adds_constants_to_class
    o = @c::C.new

    assert_equal :bar, o.foo

    assert_raises(NameError) { @c::D }

    
  end
end

class DefaultModuleWithReexportedConstantsTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_default_module_includes_reexported_constants
    @m = import('./modules/default_module')
    assert_equal("forty two", @m::CONST)
    assert_equal("hello!", @m::ImportedClass.new.greet)
  end
end

class GemTest < MiniTest::Test
  def setup
    Object.remove_const(:MyGem) rescue nil
  end

  def teardown
    Object.remove_const(:MyGem) rescue nil
    Modulation.reset!
  end

  def test_that_a_required_gem_defines_its_namespace
    require_relative './modules/my_gem'

    assert(MyGem.is_a?(Module))

    assert_equal("forty two", MyGem::CONST)
    assert_kind_of(Class, MyGem::MyClass)
    assert_equal("hello!", MyGem::MyClass.new.greet)
  end

  def test_that_an_imported_gem_exports_its_namespace
    @m = import('./modules/my_gem')

    assert_equal("forty two", @m::CONST)
    assert_kind_of(Class, @m::MyClass)
    assert_equal("hello!", @m::MyClass.new.greet)
  end

  def test_that_importing_a_regular_gem_raises_error
    e = assert_raises(LoadError) { import('redis/hash_ring') }
    assert_match(/use `require` instead/, e.message)

    e = assert_raises(LoadError) { import('redis') }
    assert_match(/use `require` instead/, e.message)
  end
end

class ModuleRefTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_contained_modules_have_access_to_containing_module
    m = import('./modules/contained')
    
    assert_equal(42, m.meaning_of_life)
    assert_equal(42, m::ContainedModule.test)

    assert_raises(NameError) {m::ContainedModule.test_private}
  end
end

class CircularRefTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_circular_references_work
    m1 = import('./modules/circular1')
    m2 = import('./modules/circular2')

    assert_equal(42, m1.meaning_of_life)
    assert_equal(42, m2.reexported)
  end
end

class InstanceVariablesTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_instance_variables_are_accessible
    m = import('./modules/instance_vars')
    assert_nil(m.get)
    m.set(42)
    assert_equal(42, m.get)

    assert_nil(m.name)
    m.name = 'abc'
    assert_equal('abc', m.name)
  end
end

require 'fileutils'

class ReloadTest < MiniTest::Test
  def teardown
    FileUtils.rm(RELOADED_FN)
    Modulation.reset!
  end

  def write_template(fn)
    File.open(RELOADED_FN, 'w+') {|f| f << IO.read(fn)}
  end

  def test_that_a_module_can_be_reloaded
    write_template(File.join(MODULES_DIR, 'template_reloaded_1.rb'))
    m = import('./modules/reloaded_user')
    
    assert_equal(m.call_me, 'Saul')
    assert_equal(m.hide_and_seek, 42)

    write_template(File.join(MODULES_DIR, 'template_reloaded_2.rb'))
    m.reload_dependency

    assert_equal(m.call_me, 'David')
    assert_raises(NameError) {m.hide_and_seek}
  end

  def test_that_a_module_can_be_reloaded_without_breaking_deps
    write_template(File.join(MODULES_DIR, 'template_reloaded_1.rb'))
    m = import('./modules/reloaded_user')
    
    assert_equal(m.call_me, 'Saul')
    assert_equal(m.hide_and_seek, 42)

    write_template(File.join(MODULES_DIR, 'template_reloaded_2.rb'))
    Modulation.reload(RELOADED_FN)

    assert_equal(m.call_me, 'David')
    assert_raises(NameError) {m.hide_and_seek}
  end

  def test_reloading_by_filename
    write_template(File.join(MODULES_DIR, 'template_reloaded_1.rb'))
    m = import('./modules/reloaded_user')
    
    assert_equal(m.call_me, 'Saul')
    assert_equal(m.hide_and_seek, 42)

    write_template(File.join(MODULES_DIR, 'template_reloaded_2.rb'))
    Modulation.reload(RELOADED_FN)

    assert_equal(m.call_me, 'David')
    assert_raises(NameError) {m.hide_and_seek}
  end

  def test_that_a_default_export_can_be_reloaded
    write_template(File.join(MODULES_DIR, 'template_reloaded_default_1.rb'))
    m = import('./modules/reloaded')
    
    assert_kind_of(String, m)
    assert_equal("Hello", m)

    write_template(File.join(MODULES_DIR, 'template_reloaded_default_2.rb'))
    m = m.__reload!

    assert_kind_of(Hash, m)
    assert_equal({"Hello" => "world"}, m)
  end
end

class MockTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  module Mockery
    extend self
    
    def message
      'mocked'
    end

    SQL = 'select id from mocked'
  end

  def test_unmocked_module_user
    m = import('./modules/mock_user')
    assert_equal('not mocked', m.message)
    assert_equal('select id from not_mocked', m.sql_const)
  end

  def test_that_mock_with_block_provides_a_mock_module
    Modulation.mock('./modules/mocked', Mockery) do
      m = import('./modules/mock_user')
      assert_equal('mocked', m.message)
      assert_equal('select id from mocked', m.sql_const)
    end
  end
end

class ModuleTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_transitive_module_can_be_included_in_module
    m = import('./modules/include_module')
    assert_equal('bar', m.foo)
  end
end

class InstanceVariableTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_instance_variables_can_be_set_outside_of_methods
    m = import('./modules/instance_var')
    assert_equal('bar', m.foo)
  end
end

class AutoImportTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_auto_import_loads_module
    m = import('./modules/auto_import')

    fn1 = File.expand_path('modules/auto_import.rb', File.dirname(__FILE__))
    assert_equal([fn1], Modulation.loaded_modules.keys)

    assert_equal('bar', m.foo)
    
    fn2 = File.expand_path('modules/auto_import_bar.rb', File.dirname(__FILE__))
    assert_equal([fn1, fn2], Modulation.loaded_modules.keys)
  end

  def test_auto_import_in_nested_module
    m = import('./modules/auto_import_nested')

    fn1 = File.expand_path('modules/auto_import_nested.rb', File.dirname(__FILE__))
    assert_equal([fn1], Modulation.loaded_modules.keys)

    assert_equal('bar', m::BAR)
    
    fn2 = File.expand_path('modules/auto_import_bar.rb', File.dirname(__FILE__))
    assert_equal([fn1, fn2], Modulation.loaded_modules.keys)
  end

  def test_auto_import_with_hash_argument
    m = import('./modules/auto_import_hash')

    fn1 = File.expand_path('modules/auto_import_hash.rb', File.dirname(__FILE__))
    assert_equal([fn1], Modulation.loaded_modules.keys)

    assert_equal('bar', m::M::BAR)
    
    fn2 = File.expand_path('modules/auto_import_bar.rb', File.dirname(__FILE__))
    assert_equal([fn1, fn2], Modulation.loaded_modules.keys)

    assert_equal('baz', m::M::BAZ)
    
    fn3 = File.expand_path('modules/auto_import_baz.rb', File.dirname(__FILE__))
    assert_equal([fn1, fn2, fn3], Modulation.loaded_modules.keys)
  end
end

class ImportAllTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_import_all_loads_all_files_matching_pattern
    m = import_all('./modules/subdir')
    fn_a = File.expand_path('./modules/subdir/a.rb', __dir__)
    fn_b = File.expand_path('./modules/subdir/b.rb', __dir__)
    fn_c1 = File.expand_path('./modules/subdir/c1.rb', __dir__)
    fn_c2 = File.expand_path('./modules/subdir/c2.rb', __dir__)
    
    assert_equal([fn_a, fn_b, fn_c1, fn_c2], Modulation.loaded_modules.keys.sort) 
  end
end