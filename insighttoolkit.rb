class Insighttoolkit < Formula
  desc "ITK is a toolkit for performing registration and segmentation"
  homepage "http://www.itk.org"
  url "https://downloads.sourceforge.net/project/itk/itk/4.11/InsightToolkit-4.11.0.tar.gz"
  sha256 "26f63efa290a86f10a3686cf3fa2aa3ef7420f3dc33112e2900b7dc8f9a50afe"
  revision 2
  head "git://itk.org/ITK.git"

  bottle do
    sha256 "4c3b796e7a1637066b828493f9af773c72bbd33e20e473dd5ed6faec2e550640" => :sierra
    sha256 "6aa4d5fc679421b44aaff02ec935ab9a0c309968b9f3f4859a00d37bf1800228" => :el_capitan
    sha256 "3da2ec4a7016ae11ec401309850944f9ec1a8f8e4eac6c65440f6fb2244d049b" => :yosemite
    sha256 "80b43d0e5af42c1cd8b701f0f0d092f60b396b8e90e059eacdb853f3cfe48738" => :x86_64_linux
  end

  option :cxx11
  option "with-examples", "Compile and install various examples"
  option "with-itkv3-compatibility", "Include ITKv3 compatibility"
  option "with-remove-legacy", "Disable legacy APIs"

  deprecated_option "examples" => "with-examples"
  deprecated_option "remove-legacy" => "with-remove-legacy"

  cxx11dep = build.cxx11? ? ["c++11"] : []

  depends_on "cmake" => :build
  depends_on "opencv" => [:optional] + cxx11dep
  depends_on :python => :optional
  depends_on :python3 => :optional
  depends_on "fftw" => :recommended
  depends_on "hdf5" => [:recommended] + cxx11dep
  depends_on "jpeg" => :recommended
  depends_on "libpng" => :recommended
  depends_on "libtiff" => :recommended
  depends_on "gdcm" => [:optional] + cxx11dep
  depends_on "expat" unless OS.mac?

  if build.with? "python3"
    depends_on "vtk" => [:build, "with-python3", "without-python"] + cxx11dep
  elsif build.with? "python"
    depends_on "vtk" => [:build, "with-python"] + cxx11dep
  else
    depends_on "vtk" => [:build] + cxx11dep
  end

  def install
    dylib = OS.mac? ? "dylib" : "so"

    args = std_cmake_args + %W[
      -DBUILD_TESTING=OFF
      -DBUILD_SHARED_LIBS=ON
      -DITK_USE_64BITS_IDS=ON
      -DITK_USE_STRICT_CONCEPT_CHECKING=ON
      -DITK_USE_SYSTEM_ZLIB=ON
      -DITK_USE_SYSTEM_EXPAT=ON
      -DCMAKE_INSTALL_RPATH:STRING=#{lib}
      -DCMAKE_INSTALL_NAME_DIR:STRING=#{lib}
      -DModule_SCIFIO=ON
    ]
    args << ".."
    args << "-DBUILD_EXAMPLES=" + ((build.include? "examples") ? "ON" : "OFF")
    args << "-DModule_ITKVideoBridgeOpenCV=" + ((build.with? "opencv") ? "ON" : "OFF")
    args << "-DITKV3_COMPATIBILITY:BOOL=" + ((build.with? "itkv3-compatibility") ? "ON" : "OFF")

    args << "-DITK_USE_SYSTEM_FFTW=ON" << "-DITK_USE_FFTWF=ON" << "-DITK_USE_FFTWD=ON" if build.with? "fftw"
    args << "-DITK_USE_SYSTEM_HDF5=ON" if build.with? "hdf5"
    args << "-DITK_USE_SYSTEM_JPEG=ON" if build.with? "jpeg"
    args << "-DITK_USE_SYSTEM_PNG=ON" if build.with? :libpng
    args << "-DITK_USE_SYSTEM_TIFF=ON" if build.with? "libtiff"
    args << "-DITK_USE_SYSTEM_GDCM=ON" if build.with? "gdcm"
    args << "-DITK_LEGACY_REMOVE=ON" if build.include? "remove-legacy"
    args << "-DModule_ITKLevelSetsv4Visualization=ON"
    args << "-DModule_ITKReview=ON"
    args << "-DModule_ITKVtkGlue=ON"
    args << "-DITK_USE_GPU=" + (OS.mac? ? "ON" : "OFF")

    args << "-DVCL_INCLUDE_CXX_0X=ON" if build.cxx11?
    ENV.cxx11 if build.cxx11?

    mkdir "itk-build" do
      if build.with?("python") || build.with?("python3")
        python_executable = `which python`.strip if build.with? "python"
        python_executable = `which python3`.strip if build.with? "python3"

        python_prefix = `#{python_executable} -c 'import sys;print(sys.prefix)'`.chomp
        python_include = `#{python_executable} -c 'from distutils import sysconfig;print(sysconfig.get_python_inc(True))'`.chomp
        python_version = "python" + `#{python_executable} -c 'import sys;print(sys.version[:3])'`.chomp

        args << "-DITK_WRAP_PYTHON=ON"
        args << "-DPYTHON_EXECUTABLE='#{python_executable}'"
        args << "-DPYTHON_INCLUDE_DIR='#{python_include}'"
        # CMake picks up the system's python dylib, even if we have a brewed one.
        if File.exist? "#{python_prefix}/Python"
          args << "-DPYTHON_LIBRARY='#{python_prefix}/Python'"
        elsif File.exist? "#{python_prefix}/lib/lib#{python_version}.a"
          args << "-DPYTHON_LIBRARY='#{python_prefix}/lib/lib#{python_version}.a'"
        elsif File.exist? "#{python_prefix}/lib/lib#{python_version}.#{dylib}"
          args << "-DPYTHON_LIBRARY='#{python_prefix}/lib/lib#{python_version}.#{dylib}'"
        elsif File.exist? "#{python_prefix}/lib/x86_64-linux-gnu/lib#{python_version}.#{dylib}"
          args << "-DPYTHON_LIBRARY='#{python_prefix}/lib/x86_64-linux-gnu/lib#{python_version}.#{dylib}'"
        else
          odie "No libpythonX.Y.{dylib|so|a} file found!"
        end
      end
      system "cmake", *args
      system "make", "install"
    end
  end

  test do
    (testpath/"test.cxx").write <<-EOS
      #include "itkImage.h"

      int main(int argc, char* argv[])
      {
        typedef itk::Image< unsigned short, 3 > ImageType;
        ImageType::Pointer image = ImageType::New();
        image->Update();

        return EXIT_SUCCESS;
      }
    EOS

    dylib = OS.mac? ? "1.dylib" : "so.1"
    v=version.to_s.split(".")[0..1].join(".")
    # Build step
    system ENV.cxx, "-isystem", "#{include}/ITK-#{v}", "-o", "test.cxx.o", "-c", "test.cxx"
    # Linking step
    system ENV.cxx, "test.cxx.o", "-o", "test",
                    "#{lib}/libITKCommon-#{v}.#{dylib}",
                    "#{lib}/libITKVNLInstantiation-#{v}.#{dylib}",
                    "#{lib}/libitkvnl_algo-#{v}.#{dylib}",
                    "#{lib}/libitkvnl-#{v}.#{dylib}"
    system "./test"
  end
end
