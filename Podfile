platform :ios, '16.0'
use_frameworks!

target 'GithubSearch' do
  pod 'SwiftLint', '~> 0.54'
  pod 'RxSwift', '~> 6.9.0'
  pod 'RxCocoa', '~> 6.9.0'
  pod 'SnapKit', '~> 5.7.0'

  target 'GithubSearchTests' do
    inherit! :search_paths
    pod 'RxTest', '~> 6.9.0'
    pod 'RxBlocking', '~> 6.9.0'
  end
end


post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    end
  end
end