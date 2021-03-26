# frozen_string_literal: true

require 'find'
require 'mkmf'
require 'pathname'

LIBMAGIC_TAG = '5.39'
LIBIMAGE_SHA256 = 'f05d286a76d9556243d0cb05814929c2ecf3a5ba07963f8f70bfaaa70517fad1'

# helpful constants
PACKAGE_ROOT_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))

# The gem version constraint in the Rakefile is not respected at install time.
# Keep this version in sync with the one in the Rakefile !
REQUIRED_MINI_PORTILE_VERSION = "~> 2.5.0"

MAGIC_HELP_MESSAGE = <<~HELP
  USAGE: ruby #{$0} [options]

    Flags that are always valid:

      --use-system-libraries
      --enable-system-libraries
          Use system libraries instead of building and using the packaged libraries.

      --disable-system-libraries
          Use the packaged libraries, and ignore the system libraries. This is the default on most
          platforms, and overrides `--use-system-libraries` and the environment variable
          `RB_MAGIC_USE_SYSTEM_LIBRARIES`.

      --disable-clean
          Do not clean out intermediate files after successful build.

    Flags only used when building and using the packaged libraries:

      --disable-static
          Do not statically link packaged libraries, instead use shared libraries.

      --enable-cross-build
          Enable cross-build mode. (You probably do not want to set this manually.)

    Flags only used when using system libraries:

      Related to libmagic:

        --with-magic-dir=DIRECTORY
            Look for libmagic headers and library in DIRECTORY.

        --with-magic-lib=DIRECTORY
            Look for libmagic library in DIRECTORY.

        --with-magic-include=DIRECTORY
            Look for libmagic headers in DIRECTORY.

    Environment variables used:

      CC
          Use this path to invoke the compiler instead of `RbConfig::CONFIG['CC']`

      CPPFLAGS
          If this string is accepted by the C preprocessor, add it to the flags passed to the C preprocessor

      CFLAGS
          If this string is accepted by the compiler, add it to the flags passed to the compiler

      LDFLAGS
          If this string is accepted by the linker, add it to the flags passed to the linker

      LIBS
          Add this string to the flags passed to the linker
HELP

def process_recipe(name, version, static_p, cross_p)
  require 'rubygems'
  gem('mini_portile2', REQUIRED_MINI_PORTILE_VERSION)
  require 'mini_portile2'
  message("Using mini_portile version #{MiniPortile::VERSION}\n")

  MiniPortile.new(name, version).tap do |recipe|
    # Prefer host_alias over host in order to use i586-mingw32msvc as
    # correct compiler prefix for cross build, but use host if not set.
    recipe.host = RbConfig::CONFIG["host_alias"].empty? ? RbConfig::CONFIG["host"] : RbConfig::CONFIG["host_alias"]
    recipe.target = File.join(PACKAGE_ROOT_DIR, "ports")
    recipe.configure_options << "--libdir=#{File.join(recipe.path, 'lib')}"

    yield recipe

    env = Hash.new do |hash, key|
      hash[key] = (ENV[key]).to_s
    end

    recipe.configure_options.flatten!

    recipe.configure_options = [
      "--disable-silent-rules",
      "--disable-dependency-tracking",
      "--enable-fsect-man5"
    ]

    if static_p
      recipe.configure_options += [
        "--disable-shared",
        "--enable-static",
      ]
      env["CFLAGS"] = concat_flags(env["CFLAGS"], "-fPIC")
    else
      recipe.configure_options += [
        "--enable-shared",
        "--disable-static",
      ]
    end

    if cross_p
      recipe.configure_options += [
        "--target=#{recipe.host}",
        "--host=#{recipe.host}",
      ]
    end

    recipe.configure_options += env.map do |key, value|
      "#{key}=#{value.strip}"
    end

    recipe.cook
    recipe.activate
  end
end

#
#  utility functions
#
def config_clean?
  enable_config('clean', true)
end

def config_static?
  default_static = !truffle?
  enable_config("static", default_static)
end

def config_cross_build?
  enable_config("cross-build")
end

def config_system_libraries?
  enable_config("system-libraries", ENV.key?("RB_MAGIC_USE_SYSTEM_LIBRARIES")) do |_, default|
    arg_config('--use-system-libraries', default)
  end
end

def darwin?
  RbConfig::CONFIG['target_os'] =~ /darwin/
end

def windows?
  RbConfig::CONFIG['target_os'] =~ /mswin|mingw32|windows/
end

def truffle?
  ::RUBY_ENGINE == 'truffleruby'
end

def concat_flags(*args)
  args.compact.join(" ")
end

def do_help
  print(MAGIC_HELP_MESSAGE)
  exit!(0)
end

def do_clean
  root = Pathname(PACKAGE_ROOT_DIR)
  pwd  = Pathname(Dir.pwd)

  # Skip if this is a development work tree
  unless (root + '.git').exist?
    message("Cleaning files only used during build.\n")

    # (root + 'tmp') cannot be removed at this stage because
    # libmagic.so is yet to be copied to lib.

    # clean the ports build directory
    Pathname.glob(pwd.join('tmp', '*', 'ports')) do |dir|
      FileUtils.rm_rf(dir, verbose: true)
    end

    FileUtils.rm_rf(root + 'ports' + 'archives', verbose: true)

    if config_static?
      # Remove everything but share/ directory
      Find.find(root + 'ports').each do |filename|
        FileUtils.rm_f(filename, verbose: true) unless filename.include?('/share')
      end
    end
  end

  exit!(0)
end

#
#  main
#
do_help if arg_config('--help')
do_clean if arg_config('--clean')

if config_system_libraries?
  message "Building ruby-magic using system libraries.\n"

  dir_config('magic')
else
  message "Building ruby-magic using packaged libraries.\n"

  static_p = config_static?
  message "Static linking is #{static_p ? 'enabled' : 'disabled'}.\n"
  cross_build_p = config_cross_build?
  message "Cross build is #{cross_build_p ? 'enabled' : 'disabled'}.\n"

  libmagic_recipe = process_recipe('libmagic', LIBMAGIC_TAG, static_p, cross_build_p) do |recipe|
    recipe.files = [{
                      url: "https://ruby-magic.s3.eu-central-1.amazonaws.com/file-#{recipe.version}.tar.gz",
                      sha256: LIBIMAGE_SHA256
                    }]
  end

  $LIBPATH = [File.join(libmagic_recipe.path, 'lib')]
  $CFLAGS << " -I#{File.join(libmagic_recipe.path, 'include')} "

  if static_p
    ENV['PKG_CONFIG_PATH'] = "#{libmagic_recipe.path}/lib/pkgconfig"
    # mkmf appends -- to the first option
    $LIBS += " " + pkg_config('libmagic', 'libs --static')
    $LDFLAGS.gsub!('-lmagic', '')
    $LIBS.gsub!('-lmagic', '')
    $LIBS += " " + File.join(libmagic_recipe.path, 'lib', "libmagic.#{$LIBEXT}")
  end
end

if ENV['CC']
  RbConfig::CONFIG['CC'] = RbConfig::MAKEFILE_CONFIG['CC'] = ENV['CC']
end

ENV['CC'] = RbConfig::CONFIG['CC']

$CFLAGS += ' -std=c99 -fPIC'
$CFLAGS += ' -Wall -Wextra -pedantic'

if RbConfig::CONFIG['CC'] =~ /gcc/
  $CFLAGS += ' -O3' unless $CFLAGS =~ /-O\d/
  $CFLAGS += ' -Wcast-qual -Wwrite-strings -Wconversion -Wmissing-noreturn -Winline'
end

unless darwin?
  $LDFLAGS += ' -Wl,--as-needed -Wl,--no-undefined'
end

if windows?
  $LDFLAGS += ' -static-libgcc'
end

%w[
  CFLAGS
  CXXFLAGS
  CPPFLAGS
].each do |variable|
  $CFLAGS += format(' %s', ENV[variable]) if ENV[variable]
end

$LDFLAGS += format(' %s', ENV['LDFLAGS']) if ENV['LDFLAGS']

unless have_header('ruby.h')
  abort "\n" + (<<-EOS).gsub(/^[ ]{,3}/, '') + "\n"
    You appear to be missing Ruby development libraries and/or header
    files. You can install missing compile-time dependencies in one of
    the following ways:

    - Debian / Ubuntu

        apt-get install ruby-dev

    - Red Hat / CentOS / Fedora

        yum install ruby-devel or dnf install ruby-devel

    - Mac OS X (Darwin)

        brew install ruby (for Homebrew, see https://brew.sh)
        port install ruby2.6 (for MacPorts, see https://www.macports.org)

    - OpenBSD / NetBSD

        pkg_add ruby (for pkgsrc, see https://www.pkgsrc.org)

    - FreeBSD

        pkg install ruby (for FreeBSD Ports, see https://www.freebsd.org/ports)

    Alternatively, you can use either of the following Ruby version
    managers in order to install Ruby locally (for your user only)
    and/or system-wide:

    - Ruby Version Manager (for RVM, see https://rvm.io)
    - Ruby Environment (for rbenv, see https://github.com/sstephenson/rbenv)
    - Change Ruby (for chruby, see https://github.com/postmodern/chruby)

    More information about how to install Ruby on various platforms
    available at the following web site:

      https://www.ruby-lang.org/en/documentation/installation
  EOS
end

have_func('rb_thread_call_without_gvl')
have_func('rb_thread_blocking_region')

unless have_header('magic.h')
  abort "\n" + (<<-EOS).gsub(/^[ ]{,3}/, '') + "\n"
    You appear to be missing libmagic(3) library and/or necessary header
    files. You can install missing compile-time dependencies in one of
    the following ways:

    - Debian / Ubuntu

        apt-get install libmagic-dev

    - Red Hat / CentOS / Fedora

        yum install file-devel or dns install file-devel

    - Mac OS X (Darwin)

        brew install libmagic (for Homebrew, see https://brew.sh)
        port install libmagic (for MacPorts, see https://www.macports.org)

    - OpenBSD / NetBSD

        pkg_add file (for pkgsrc, see https://www.pkgsrc.org)

    - FreeBSD

        pkg install file (for FreeBSD Ports, see https://www.freebsd.org/ports)

    Alternatively, you can download recent release of the file(1) package
    from the following web site and attempt to compile libmagic(3) manually:

      https://www.darwinsys.com/file
  EOS
end

have_library('magic')

unless have_func('magic_getpath')
  abort "\n" + (<<-EOS).gsub(/^[ ]{,3}/, '') + "\n"
    Your version of libmagic(3) appears to be too old.

    Please, consider upgrading to at least version 5.29 or newer,
    if possible. For more information about file(1) command and
    libmagic(3) please visit the following web site:

      https://www.darwinsys.com/file
  EOS
end

have_func('magic_getflags')

%w[
  utime.h
  sys/types.h
  sys/time.h
].each do |h|
  have_header(h)
end

%w[
  utime
  utimes
].each do |f|
  have_func(f)
end

create_header
create_makefile('magic/magic')

if config_clean?
  # Do not clean if run in a development work tree.
  File.open('Makefile', 'at') do |mk|
    mk.print(<<~EOF)

      all: clean-ports
      clean-ports: $(DLLIB)
      \t-$(Q)$(RUBY) $(srcdir)/extconf.rb --clean --#{static_p ? 'enable' : 'disable'}-static
    EOF
  end
end
