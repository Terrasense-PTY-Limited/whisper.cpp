Pod::Spec.new do |s|
  s.name         = 'whisper-cpp'
  s.version      = '1.0.0'
  s.summary      = 'whisper.cpp — C/C++ port of OpenAI Whisper for on-device speech recognition'
  s.homepage     = 'https://github.com/ggerganov/whisper.cpp'
  s.license      = { :type => 'MIT' }
  s.author       = 'Georgi Gerganov'
  s.source       = { :git => 'https://github.com/ggerganov/whisper.cpp.git', :tag => 'v1.7.3' }
  s.ios.deployment_target = '15.0'

  # GGML Metal needs the optional Xcode "Metal Toolchain" component; without it, xcodebuild
  # fails compiling ggml-metal.metal. Set WHISPER_NO_METAL=1 (default from Podfile) for CPU-only.
  no_metal = ENV['WHISPER_NO_METAL'] == '1'

  core_sources = [
    # whisper
    'include/whisper.h',
    'src/whisper.cpp',
    'src/whisper-arch.h',
    # ANEForge encoder hook (upstream 2026): stubbed off-device, inert unless
    # ANEFORGE_ENCODER is set, but whisper.cpp references its symbols.
    'src/aneforge/whisper-aneforge.h',
    'src/aneforge/whisper-aneforge.cpp',

    # ggml core
    'ggml/include/**/*.h',
    'ggml/src/ggml.c',
    'ggml/src/ggml.cpp',
    'ggml/src/ggml-alloc.c',
    'ggml/src/ggml-backend.cpp',
    'ggml/src/ggml-backend-reg.cpp',
    # Meta backend buffers, referenced by ggml-alloc / ggml-backend.
    'ggml/src/ggml-backend-meta.cpp',
    # Normally CMake-generated from ggml-version.h.in; checked in for us.
    'ggml/src/ggml-version.h',
    # Provides dl_load_library / dl_get_sym / dl_error for ggml-backend-reg (dynamic backend loading)
    'ggml/src/ggml-backend-dl.cpp',
    'ggml/src/ggml-opt.cpp',
    'ggml/src/ggml-quants.c',
    'ggml/src/ggml-threading.cpp',
    'ggml/src/gguf.cpp',
    'ggml/src/ggml-impl.h',
    'ggml/src/ggml-common.h',
    'ggml/src/ggml-backend-impl.h',

    # ggml-cpu
    'ggml/src/ggml-cpu/*.c',
    'ggml/src/ggml-cpu/*.cpp',
    'ggml/src/ggml-cpu/*.h',
    'ggml/src/ggml-cpu/arch/arm/*.cpp',
    'ggml/src/ggml-cpu/arch/arm/*.c',
  ]

  metal_sources = [
    'ggml/src/ggml-metal/*.cpp',
    'ggml/src/ggml-metal/*.m',
    'ggml/src/ggml-metal/*.h',
  ]

  s.source_files = no_metal ? core_sources : (core_sources + metal_sources)

  s.public_header_files = [
    'include/whisper.h',
    'ggml/include/*.h',
  ]

  unless no_metal
    s.preserve_paths = [
      'ggml/src/ggml-metal/ggml-metal.metal',
    ]
    s.resource_bundles = {
      'whisper-cpp' => ['ggml/src/ggml-metal/ggml-metal.metal'],
    }
  end

  header_paths = [
    '"${PODS_TARGET_SRCROOT}/include"',
    '"${PODS_TARGET_SRCROOT}/src"',
    '"${PODS_TARGET_SRCROOT}/ggml/include"',
    '"${PODS_TARGET_SRCROOT}/ggml/src"',
    '"${PODS_TARGET_SRCROOT}/ggml/src/ggml-cpu"',
    '"${PODS_TARGET_SRCROOT}/ggml/src/ggml-cpu/arch/arm"',
  ]
  header_paths << '"${PODS_TARGET_SRCROOT}/ggml/src/ggml-metal"' unless no_metal

  # -ffast-math implies -ffinite-math-only; ggml requires non-finite math (NaN/Inf) — see ggml-cpu/vec.h
  optflags = '-O3 -ffast-math -fno-finite-math-only'
  # CMake normally defines these; CocoaPods builds skip CMake, so provide string literals for ggml.c.
  ggml_ident = '-DGGML_VERSION=\\"0.9.8\\" -DGGML_COMMIT=\\"unknown\\" -DWHISPER_VERSION=\\"1.7.3\\"'

  if no_metal
    defs = 'GGML_USE_CPU NDEBUG'
    cflags = "#{optflags} #{ggml_ident} -DGGML_USE_CPU"
    cxxflags = "#{optflags} #{ggml_ident} -std=c++17 -DGGML_USE_CPU"
    s.frameworks = 'Accelerate', 'Foundation'
  else
    defs = 'GGML_USE_CPU GGML_USE_METAL NDEBUG GGML_METAL_EMBED_LIBRARY=0'
    cflags = "#{optflags} #{ggml_ident} -DGGML_USE_CPU -DGGML_USE_METAL"
    cxxflags = "#{optflags} #{ggml_ident} -std=c++17 -DGGML_USE_CPU -DGGML_USE_METAL"
    s.frameworks = 'Accelerate', 'Metal', 'MetalKit', 'Foundation'
  end

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => header_paths.join(' '),
    'GCC_PREPROCESSOR_DEFINITIONS' => defs,
    'OTHER_CFLAGS' => cflags,
    'OTHER_CPLUSPLUSFLAGS' => cxxflags,
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
  }
end
