# frozen_string_literal: true

require 'test/unit'
require "mocha/test_unit"
require 'magic'

require_relative 'helpers/magic_test_helper'

class MagicTest < Test::Unit::TestCase
  include MagicTestHelpers

  def setup
    @flags_limit = 0xfffffff
    @version = Magic.version rescue nil
    @magic = Magic.new

    @magic_load_buffers = @version && @version > 519
    @magic_parameters = @version && @version > 520
  end

  def test_magic_alias
    assert_same(FileMagic, Magic)
  end

  def test_magic_flags_alias
    assert_alias_method(@magic, :flags_array, :flags_to_a)
  end

  def test_magic_check_alias
    assert_alias_method(@magic, :valid?, :check)
  end

  def test_magic_version_to_a_alias
    assert_alias_method(Magic, :version_array, :version_to_a)
  end

  def test_magic_version_to_s_alias
    assert_alias_method(Magic, :version_string, :version_to_s)
  end

  def test_magic_singleton_methods
    [
      :open,
      :mime,
      :type,
      :encoding,
      :compile,
      :check,
      :file,
      :buffer,
      :descriptor,
      :version,
      :version_to_a,
      :version_to_s
    ].each {|i| assert_respond_to(Magic, i) }
  end

  def test_magic_global_singleton_methods
    [
      :do_not_auto_load,
      :do_not_auto_load=,
      :do_not_stop_on_error,
      :do_not_stop_on_error=
    ].each {|i| assert_respond_to(Magic, i) }
  end

  def test_magic_new_instance
    assert(@magic.class == Magic)
  end

  def test_magic_new_instance_default_flags
    with_attribute_override(:do_not_stop_on_error, value: true) do
      assert_equal(0, @magic.flags)
    end

    assert_equal(512, @magic.flags)
  end

  def test_magic_new_with_block
    obtained = nil

    output = capture_stderr do
      obtained = Magic.new {}
    end

    assert_kind_of(Magic, obtained)

    expected = "Magic::new() does not take block; use Magic::open() instead\n"
    assert_equal(expected, output.split(/\.rb:\d+\:\s+?|warning:\s+?/).pop)
  end

  def test_magic_instance_methods
    [
      :do_not_stop_on_error,
      :do_not_stop_on_error=,
      :open?,
      :close,
      :closed?,
      :paths,
      :get_parameter,
      :set_parameter,
      :flags,
      :flags=,
      :flags_array,
      :file,
      :buffer,
      :descriptor,
      :fd,
      :load,
      :load_buffers,
      :loaded?,
      :compile,
      :check
    ].each {|i| assert_respond_to(@magic, i) }
  end

  def test_magic_string_integration_methods
    [
      :magic,
      :mime,
      :type
    ].each {|i| assert_respond_to(String.allocate, i) }
  end

  def test_magic_file_integration_singleton_methods
    [
      :magic,
      :mime,
      :type
    ].each {|i| assert_respond_to(File, i) }
  end

  def test_magic_file_integration_instance_methods
    [
      :magic,
      :mime,
      :type
    ].each {|i| assert_respond_to(File.allocate, i) }
  end

  def test_magic_open
    assert_true(@magic.open?)
    @magic.close
    assert_false(@magic.open?)
  end

  def test_magic_close
    @magic.close
    assert_true(@magic.closed?)
  end

  def test_magic_close_twice
    assert_nothing_raised do
      @magic.close
      @magic.close
    end
  end

  def test_magic_close_error
    error = assert_raise Magic::LibraryError do
      @magic.close
      @magic.flags
    end

    assert_equal('Magic library is not open', error.message)
  end

  def test_magic_closed
    assert_false(@magic.closed?)
    @magic.close
    assert_true(@magic.closed?)
  end

  def test_magic_inspect_when_magic_open
    assert_match(%r{^#<Magic:0x.+>$}, @magic.inspect)
  end

  def test_magic_inspect_when_magic_closed
    @magic.close
    assert_match(%r{^#<Magic:0x.+ \(closed\)>$}, @magic.inspect)
  end

  def test_magic_paths
    assert_kind_of(Array, @magic.paths)
    assert_not_equal(0, @magic.paths.size)
  end

  def test_magic_paths_with_MAGIC_environment_variable
  end

  def test_magic_get_parameter_error
    if @magic_parameters
      @magic.stubs(:get_parameter).with(0).raises(Magic::NotImplementedError)
    end

    assert_raise Magic::NotImplementedError do
      @magic.get_parameter(0)
    end
  end

  def test_magic_get_parameter_error_message
    if @magic_parameters
      @magic.stubs(:get_parameter).with(0).raises(Magic::NotImplementedError, 'function is not implemented')
    end

    error = assert_raise Magic::NotImplementedError do
      @magic.get_parameter(0)
    end

    assert_equal('function is not implemented', error.message)
  end

  def test_magic_get_parameter_with_PARAM_INDIR_MAX
    unless @magic_parameters && Magic::PARAM_INDIR_MAX > -1
      omit('Magic library is too old')
    end

    # Older versions of libmagic will have lower value.
    expected = @version < 526 ? 15 : 50

    assert_equal(expected, @magic.get_parameter(Magic::PARAM_INDIR_MAX))
  end

  def test_magic_get_parameter_with_PARAM_BYTES_MAX
    unless @magic_parameters && Magic::PARAM_BYTES_MAX > -1
      omit('Magic library is too old')
    end

    assert_equal(1024 * 1024, @magic.get_parameter(Magic::PARAM_BYTES_MAX))
  end

  def test_magic_get_parameter_lower_boundary
    omit('Magic library is too old') unless @magic_parameters

    error = assert_raise Magic::ParameterError do
      @magic.get_parameter(-1)
    end

    assert_equal('unknown or invalid parameter specified', error.message)
  end

  def test_magic_get_parameter_upper_boundary
    omit('Magic library is too old') unless @magic_parameters

    error = assert_raise Magic::ParameterError do
      @magic.get_parameter(128)
    end

    assert_equal('unknown or invalid parameter specified', error.message)
  end

  def test_magic_set_parameter_error
    if @magic_parameters
      @magic.stubs(:set_parameter).with(0, 0).raises(Magic::NotImplementedError)
    end

    assert_raise Magic::NotImplementedError do
      @magic.set_parameter(0, 0)
    end
  end

  def test_magic_set_parameter_error_message
    if @magic_parameters
      @magic.stubs(:set_parameter).with(0, 0).raises(Magic::NotImplementedError, 'function is not implemented')
    end

    error = assert_raise Magic::NotImplementedError do
      @magic.set_parameter(0, 0)
    end

    assert_equal('function is not implemented', error.message)
  end

  def test_magic_set_parameter_with_PARAM_INDIR_MAX
    unless @magic_parameters && Magic::PARAM_INDIR_MAX > -1
      omit('Magic library is too old')
    end

    @magic.set_parameter(Magic::PARAM_INDIR_MAX, 128)
    assert_equal(128, @magic.get_parameter(Magic::PARAM_INDIR_MAX))
  end

  def test_magic_set_parameter_with_PARAM_BYTES_MAX
    unless @magic_parameters && Magic::PARAM_BYTES_MAX > -1
      omit('Magic library is too old')
    end

    assert_nothing_raised do
      @magic.set_parameter(Magic::PARAM_BYTES_MAX, 1024 * 1024 * 10)
    end

    assert_equal(1024 * 1024 * 10, @magic.get_parameter(Magic::PARAM_BYTES_MAX))
  end

  def test_magic_set_parameter_lower_boundary
    omit('Magic library is too old') unless @magic_parameters

    error = assert_raise Magic::ParameterError do
      @magic.set_parameter(-1, 0)
    end

    assert_equal('unknown or invalid parameter specified', error.message)
    assert_equal(Errno::EINVAL::Errno, error.errno)
  end

  def test_magic_set_parameter_upper_boundary
    omit('Magic library is too old') unless @magic_parameters

    error = assert_raise Magic::ParameterError do
      @magic.set_parameter(128, 0)
    end

    assert_equal('unknown or invalid parameter specified', error.message)
    assert_equal(Errno::EINVAL::Errno, error.errno)
  end

  def test_magic_set_parameter_value_lower_boundary
    omit('Magic library is too old') unless @magic_parameters

    assert_nothing_raised do
      @magic.set_parameter(0, 0)
    end
  end

  def test_magic_set_parameter_value_upper_boundary
    omit('Magic library is too old') unless @magic_parameters

    error = assert_raise Magic::ParameterError do
      @magic.set_parameter(0, -1)
    end

    assert_equal('invalid parameter value specified', error.message)
    assert_equal(Errno::EOVERFLOW::Errno, error.errno)
  end

  def test_magic_set_parameter_overflow_with_PARAM_INDIR_MAX
    unless @magic_parameters && Magic::PARAM_INDIR_MAX > -1
      omit('Magic library is too old')
    end

    error = assert_raise Magic::ParameterError do
      @magic.set_parameter(Magic::PARAM_INDIR_MAX, 128 * 1024)
    end

    assert_equal('invalid parameter value specified', error.message)
    assert_equal(Errno::EOVERFLOW::Errno, error.errno)
  end

  def test_magic_flags_with_NONE_flag
    @magic.flags = 0x000000 # Flag: NONE

    assert_kind_of(Integer, @magic.flags)

    with_attribute_override(:do_not_stop_on_error, value: true) do
      assert_equal(Magic::NONE, @magic.flags)
    end

    assert_equal(Magic::NONE | Magic::ERROR, @magic.flags)
  end

  def test_magic_flags_with_MIME_TYPE_flag
    @magic.flags = 0x000010 # Flag: MIME_TYPE

    assert_kind_of(Integer, @magic.flags)

    with_attribute_override(:do_not_stop_on_error, value: true) do
      assert_equal(Magic::MIME_TYPE, @magic.flags)
    end

    assert_equal(Magic::MIME_TYPE | Magic::ERROR, @magic.flags)
  end

  def test_magic_flags_with_MIME_ENCODING_flag
    @magic.flags = 0x000400 # Flag: MIME_ENCODING

    assert_kind_of(Integer, @magic.flags)

    with_attribute_override(:do_not_stop_on_error, value: true) do
      assert_equal(Magic::MIME_ENCODING, @magic.flags)
    end

    assert_equal(Magic::MIME_ENCODING | Magic::ERROR, @magic.flags)
  end

  def test_magic_flags_with_MIME_flag
    @magic.flags = 0x000410 # Flag: MIME_TYPE, MIME_ENCODING

    assert_kind_of(Integer, @magic.flags)

    with_attribute_override(:do_not_stop_on_error, value: true) do
      assert_equal(Magic::MIME, @magic.flags)
    end

    assert_equal(Magic::MIME | Magic::ERROR, @magic.flags)
  end

  def test_magic_flags_to_a_with_NONE_flag
    @magic.flags = Magic::NONE

    assert_kind_of(Array, @magic.flags_to_a)

    with_attribute_override(:do_not_stop_on_error, value: true) do
      assert_equal([Magic::NONE], @magic.flags_to_a)
    end

    assert_equal([Magic::ERROR], @magic.flags_to_a)
  end

  def test_magic_flags_to_a_with_MIME_TYPE_flag
    @magic.flags = Magic::MIME_TYPE

    assert_kind_of(Array, @magic.flags_to_a)

    with_attribute_override(:do_not_stop_on_error, value: true) do
      assert_equal([Magic::MIME_TYPE], @magic.flags_to_a)
    end

    assert_equal([Magic::MIME_TYPE, Magic::ERROR], @magic.flags_to_a)
  end

  def test_magic_flags_to_a_with_MIME_ENCODING_flag
    @magic.flags = Magic::MIME_ENCODING

    assert_kind_of(Array, @magic.flags_to_a)

    with_attribute_override(:do_not_stop_on_error, value: true) do
      assert_equal([Magic::MIME_ENCODING], @magic.flags_to_a)
    end

    assert_equal([Magic::ERROR, Magic::MIME_ENCODING], @magic.flags_to_a)
  end

  def test_magic_flags_to_a_with_MIME_flag
    @magic.flags = Magic::MIME_TYPE | Magic::MIME_ENCODING

    assert_kind_of(Array, @magic.flags_to_a)

    with_attribute_override(:do_not_stop_on_error, value: true) do
      assert_equal([Magic::MIME_TYPE, Magic::MIME_ENCODING], @magic.flags_to_a)
    end

    assert_equal([Magic::MIME_TYPE, Magic::ERROR, Magic::MIME_ENCODING], @magic.flags_to_a)
  end

  def test_magic_flags_to_a_with_NONE_flag_and_argument_true
    @magic.flags = Magic::NONE

    assert_kind_of(Array, @magic.flags_to_a)

    with_attribute_override(:do_not_stop_on_error, value: true) do
      assert_equal(['NONE'], @magic.flags_to_a(true))
    end

    assert_equal(['ERROR'], @magic.flags_to_a(true))
  end

  def test_magic_flags_to_a_with_MIME_TYPE_flag_and_argument_true
    @magic.flags = Magic::MIME_TYPE

    assert_kind_of(Array, @magic.flags_to_a)

    with_attribute_override(:do_not_stop_on_error, value: true) do
      assert_equal(['MIME_TYPE'], @magic.flags_to_a(true))
    end

    assert_equal(['MIME_TYPE', 'ERROR'], @magic.flags_to_a(true))
  end

  def test_magic_flags_to_a_with_MIME_ENCODING_flag_and_argument_true
    @magic.flags = Magic::MIME_ENCODING

    assert_kind_of(Array, @magic.flags_to_a)

    with_attribute_override(:do_not_stop_on_error, value: true) do
      assert_equal(['MIME_ENCODING'], @magic.flags_to_a(true))
    end

    assert_equal(['ERROR', 'MIME_ENCODING'], @magic.flags_to_a(true))
  end

  def test_magic_flags_to_a_with_MIME_flag_and_argument_true
    @magic.flags = Magic::MIME_TYPE | Magic::MIME_ENCODING

    assert_kind_of(Array, @magic.flags_to_a)

    with_attribute_override(:do_not_stop_on_error, value: true) do
      assert_equal(['MIME_TYPE', 'MIME_ENCODING'], @magic.flags_to_a(true))
    end

    assert_equal(['MIME_TYPE', 'ERROR', 'MIME_ENCODING'], @magic.flags_to_a(true))
  end

  def test_magic_flags_error_lower_boundary
    error = assert_raise Magic::FlagsError do
      @magic.flags = -@flags_limit
    end

    assert_equal('unknown or invalid flag specified', error.message)
    assert_equal(Errno::EINVAL::Errno, error.errno)
  end

  def test_magic_flags_error_upper_boundary
    error = assert_raise Magic::FlagsError do
      @magic.flags = @flags_limit + 1
    end

    assert_equal('unknown or invalid flag specified', error.message)
    assert_equal(Errno::EINVAL::Errno, error.errno)
  end

  def test_magic_do_not_stop_on_error
  end

  def test_magic_do_not_stop_on_error_set_globally
  end

  def test_magic_file
  end

  def test_magic_file_with_do_not_stop_on_error_set
  end

  def test_magic_file_with_do_not_stop_on_error_set_globally
  end

  def test_magic_file_with_nil_argument
    error = assert_raise TypeError do
      @magic.file nil
    end

    assert_equal('wrong argument type nil (expected String or IO-like object)', error.message)
  end

  def test_magic_file_argument_with_NULL
    assert_raise ArgumentError do
      @magic.file "string\0value"
    end
  end

  def test_magic_file_with_IO_like_argument
    with_fixtures do |_, format|
      @magic.load(File.join(format, 'png-fake.magic'))
      File.open('ruby.png') do |file|
        assert_match(%r{^Ruby Gem image}, @magic.file(file))
        assert_false(file.closed?)
      end
    end
  end

  def test_magic_file_with_IO_like_argument_stream_closed
    error = assert_raise IOError do
      IO.pipe do |r, w|
        r.close
        @magic.file r
      end
    end

    assert_equal('closed stream', error.message)
  end

  def test_magic_file_with_String_like_argument
    require 'pathname'

    with_fixtures do |_, format|
      @magic.load(File.join(format, 'png-fake.magic'))

      assert_match(%r{^Ruby Gem image}, @magic.file(Pathname.new('ruby.png')))
    end
  end

  def test_magic_file_with_ERROR_flag
  end

  def test_magic_file_with_MAGIC_CONTINUE_flag
  end

  def test_magic_file_with_EXTENSION_flag
  end

  def test_magic_buffer
  end

  def test_magic_buffer_with_nil_argument
    error = assert_raise TypeError do
      @magic.buffer nil
    end

    assert_equal('wrong argument type nil (expected String)', error.message)
  end

  def test_magic_buffer_argument_with_NULL
    assert_nothing_raised do
      @magic.buffer "string\0value"
    end
  end

  def test_magic_buffer_with_MAGIC_CONTINUE_flag
  end

  def test_magic_buffer_with_EXTENSION_flag
  end

  def test_magic_descriptor
    with_fixtures do |_, format|
      @magic.load(File.join(format, 'png-fake.magic'))

      File.open('ruby.png') do |file|
        assert_match(%r{^Ruby Gem image}, @magic.descriptor(file.fileno))
        assert_false(file.closed?)
      end
    end
  end

  def test_magic_descriptor_with_nil_argument
    error = assert_raise TypeError do
      @magic.descriptor nil
    end

    expected = format('wrong argument type nil (expected %s)', 0.class)
    assert_equal(expected, error.message)
  end

  def test_magic_descriptor_with_invalid_descriptor
    error = assert_raise IOError do
      @magic.descriptor(-1)
    end

    assert_equal('Bad file descriptor', error.message)
  end

  def test_magic_descriptor_with_descriptor_closed
    error = assert_raise IOError do
      IO.pipe do |r, w|
        r.close
        @magic.descriptor r.fileno
      end
    end

    assert_equal('closed stream', error.message)
  end

  def test_magic_descriptor_with_old_descriptor_open
  end

  def test_magic_descriptor_with_MAGIC_CONTINUE_flag
  end

  def test_magic_descriptor_with_EXTENSION_flag
  end

  def test_magic_fd_with_integer
  end

  def test_magic_fd_with_object
  end

  def test_magic_load
  end

  def test_magic_load_with_DEBUG_flag
    @magic.flags = Magic::DEBUG

    assert_kind_of(Integer, @magic.flags)

    with_attribute_override(:do_not_stop_on_error, value: true) do
      assert_equal(Magic::DEBUG, @magic.flags)
    end

    output = capture_stderr(children: true) do
      with_fixtures do
        assert_raise Magic::MagicError do
          @magic.load('invalid.magic')
        end
      end
    end

    assert_match(%r{^.+Not a valid Magic file!}, output)
  end

  def test_magic_load_with_do_not_auto_load_set
  end

  def test_magic_load_with_array_argument
  end

  def test_magic_load_with_custom_Magic_file_path
  end

  def test_magic_with_new_instance_custom_Magic_file_path
  end

  def test_magic_load_with_MAGIC_environment_variable
  end

  def test_magic_load_buffers
    omit('Magic library is too old') unless @magic_load_buffers
  end

  def test_magic_load_buffers_with_array_argument
    omit('Magic library is too old') unless @magic_load_buffers
  end

  def test_magic_load_buffers_with_DEBUG_flag
    omit('Magic library is too old') unless @magic_load_buffers
  end

  def test_magic_loaded
  end

  def test_magic_loaded_with_do_not_auto_load_set
  end

  def test_magic_check
  end

  def test_magic_check_with_DEBUG_flag
    @magic.flags = Magic::DEBUG

    assert_kind_of(Integer, @magic.flags)

    with_attribute_override(:do_not_stop_on_error, value: true) do
      assert_equal(Magic::DEBUG, @magic.flags)
    end

    output = capture_stderr(children: true) do
      with_fixtures do
        assert_nothing_raised do
          @magic.check('invalid.magic')
        end
      end
     end

    assert_match(%r{^.+Not a valid Magic file!}, output)
  end

  def test_magic_compile
  end

  def test_magic_compile_with_DEBUG_flag
  end

  def test_magic_version
    if @version.nil? || @version < 0
      Magic.stubs(:version).returns(518)
    end

    assert_kind_of(Integer, Magic.version)
    assert(Magic.version > 0)
  end

  def test_magic_version_error
    if @version
      Magic.stubs(:version).raises(Magic::NotImplementedError)
    end

    assert_raise Magic::NotImplementedError do
      Magic.version
    end
  end

  def test_magic_version_error_message
    if @version
      Magic.stubs(:version).raises(Magic::NotImplementedError, 'function is not implemented')
    end

    error = assert_raise Magic::NotImplementedError do
      Magic.version
    end

    assert_equal('function is not implemented', error.message)
  end

  def test_magic_version_to_a
    if @version.nil? || @version < 0
      Magic.stubs(:version).returns(518)
    end

    expected = [Magic.version / 100, Magic.version % 100]

    assert_equal(expected, Magic.version_to_a)
  end

  def test_magic_version_to_s
    if @version.nil? || @version < 0
      Magic.stubs(:version).returns(518)
    end

    expected = '%d.%02d' % Magic.version_to_a

    assert_equal(expected, Magic.version_to_s)
  end

  def test_magic_singleton_do_not_auto_load_global
  end

  def test_magic_singleton_do_not_auto_load
    fork do
      Magic.do_not_auto_load = true

      magic_1 = Magic.new
      magic_2 = Magic.new

      error_1 = assert_raise Magic::MagicError do
        magic_1.buffer ''
      end

      magic_1.close

      error_2 = assert_raise Magic::MagicError do
        magic_2.buffer ''
      end

      magic_2.close

      assert_equal('no magic files loaded', error_1.message)
      assert_equal('no magic files loaded', error_2.message)

      assert_true(Magic.do_not_auto_load)
    end

    Process.waitpid rescue Errno::ECHILD

    assert_false(Magic.do_not_auto_load)
  end

  def test_magic_singleton_do_not_stop_on_error_global
  end

  def test_magic_singleton_do_not_stop_on_error
  end

  def test_magic_singleton_open
  end

  def test_magic_singleton_open_custom_flag
  end

  def test_magic_singleton_open_block
  end

  def test_magic_singleton_open_block_custom_flag
  end

  def test_magic_singleton_mime
  end

  def test_magic_singleton_mime_block
  end

  def test_magic_singleton_type
  end

  def test_magic_singleton_type_block
  end

  def test_magic_singleton_encoding
  end

  def test_magic_singleton_encoding_block
  end

  def test_magic_singleton_compile
  end

  def test_magic_singleton_check
  end

  def test_magic_singleton_file
  end

  def test_magic_singleton_buffer
  end

  def test_magic_singleton_descriptor
  end

  def test_magic_magic_error
    message = 'The quick brown fox jumps over the lazy dog'
    error = Magic::Error.new(message)

    assert_respond_to(error, :errno)
    assert_equal(message, error.message)
    assert_nil(error.errno)
  end

  def test_magic_error_attribute_errno
    @magic.flags = @flags_limit + 1 # Should raise Magic::FlagsError.
  rescue Magic::Error => error
    assert_kind_of(Magic::FlagsError, error)
    assert_equal(Errno::EINVAL::Errno, error.errno)
  end

  def test_magic_new_instance_with_arguments
  end

  def test_file_integration_magic
  end

  def test_file_integration_magic_with_custom_flag
  end

  def test_file_integration_mime
  end

  def test_file_integration_type
  end

  def test_file_integration_singleton_magic
  end

  def test_file_integration_singleton_magic_with_custom_flag
  end

  def test_file_integration_singleton_mime
  end

  def test_file_integration_singleton_type
  end

  def test_string_integration_magic
  end

  def test_string_integration_magic_with_custom_flag
  end

  def test_string_integration_mime
  end

  def test_string_integration_type
  end
end
