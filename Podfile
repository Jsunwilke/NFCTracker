platform :ios, '16.0'
use_frameworks!

target 'NFC Sd Tracker' do
  # Firebase pods
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'FirebaseFirestoreSwift'
  pod 'SwiftCSV'
  
  # Add any other pods you need here...
end

# Post-install hook to fix iOS deployment target issues
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Set minimum deployment target to 16.0 for all pods
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      
      # Fix for BoringSSL-GRPC compilation issues with simulator
      if target.name == 'BoringSSL-GRPC'
        config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'i386'
        config.build_settings['EXCLUDED_ARCHS[sdk=appletvsimulator*]'] = 'i386'
        config.build_settings['EXCLUDED_ARCHS[sdk=watchsimulator*]'] = 'i386'
        
        # Override all compiler flags for simulator builds to remove -G flag
        config.build_settings['OTHER_CFLAGS'] = '-DOPENSSL_NO_ASM -w -DBORINGSSL_PREFIX=GRPC -fno-objc-arc'
        config.build_settings['OTHER_CPLUSPLUSFLAGS'] = '-DOPENSSL_NO_ASM -w -DBORINGSSL_PREFIX=GRPC -fno-objc-arc'
        config.build_settings['WARNING_CFLAGS'] = '-w'
        config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'] = 'YES'
        
        # Remove the problematic -G flag from all possible compiler flag locations
        flag_keys = ['OTHER_CFLAGS', 'OTHER_CPLUSPLUSFLAGS', 'WARNING_CFLAGS', 'GCC_WARN_INHIBIT_ALL_WARNINGS']
        flag_keys.each do |flag_key|
          if config.build_settings[flag_key]
            if config.build_settings[flag_key].is_a?(String)
              config.build_settings[flag_key] = config.build_settings[flag_key].gsub(/-G(\s|$)/, '')
            elsif config.build_settings[flag_key].is_a?(Array)
              config.build_settings[flag_key] = config.build_settings[flag_key].reject { |flag| flag == '-G' }
            end
          end
        end
      end
      
      # Additional fixes for gRPC-Core
      if target.name == 'gRPC-Core'
        config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'i386'
        config.build_settings['EXCLUDED_ARCHS[sdk=appletvsimulator*]'] = 'i386'
        config.build_settings['EXCLUDED_ARCHS[sdk=watchsimulator*]'] = 'i386'
      end
    end
    
    # Fix individual file compilation settings for BoringSSL-GRPC
    if target.name == 'BoringSSL-GRPC'
      target.source_build_phase.files.each do |build_file|
        if build_file.settings && build_file.settings['COMPILER_FLAGS']
          # Replace with clean compiler flags without -G
          build_file.settings['COMPILER_FLAGS'] = '-DOPENSSL_NO_ASM -w -DBORINGSSL_PREFIX=GRPC -fno-objc-arc'
        end
      end
    end
  end
end

