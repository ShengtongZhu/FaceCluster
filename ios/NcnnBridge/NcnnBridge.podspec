Pod::Spec.new do |s|
  s.name             = 'NcnnBridge'
  s.version          = '1.0.0'
  s.summary          = 'NCNN bridge for Dart FFI — face detection & embedding inference.'
  s.homepage         = 'https://github.com/user/face_cluster'
  s.license          = { :type => 'MIT' }
  s.author           = { 'FaceCluster' => 'dev@example.com' }
  s.source           = { :path => '.' }

  s.platform         = :ios, '13.0'
  s.static_framework = true

  # Compile ncnn_bridge.c (symlinked from android/app/src/main/cpp/)
  s.source_files     = 'ncnn_bridge.c'

  # NCNN & OpenMP prebuilt static frameworks
  s.vendored_frameworks = [
    '../Frameworks/ncnn.framework',
    '../Frameworks/openmp.framework',
  ]

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS'   => '"${PODS_ROOT}/../../ios/Frameworks/ncnn.framework/Headers"',
    'OTHER_LDFLAGS'         => '-lc++',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64',
  }

  s.frameworks = 'Accelerate'
  s.dependency 'Flutter'
end
