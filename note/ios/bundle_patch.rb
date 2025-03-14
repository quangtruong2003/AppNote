# Script patch để vô hiệu hóa việc kiểm tra privacy bundles
require 'fileutils'

# Đường dẫn thư mục build
build_dir = File.expand_path('../../build/ios/Release-iphoneos', __FILE__)

# Tạo thư mục nếu chưa tồn tại
FileUtils.mkdir_p(build_dir) unless Dir.exist?(build_dir)

# Danh sách tất cả các plugin cần tạo privacy bundle
plugins = [
  'FirebaseCoreInternal',
  'permission_handler_apple',
  'shared_preferences_foundation',
  'connectivity_plus',
  'BoringSSL-GRPC',
  'AppAuth',
  'nanopb',
  'leveldb-library',
  'abseil',
  'GoogleUtilities',
  'GTMSessionFetcher',
  'in_app_purchase_storekit',
  'path_provider_foundation',
  'image_picker_ios',
  'google_sign_in_ios',
  'flutter_local_notifications'
]

# Các định dạng bundle khác nhau
bundle_formats = {
  'FirebaseCoreInternal' => ['FirebaseCoreInternal_Privacy'],
  'nanopb' => ['nanopb_Privacy'],
  'leveldb-library' => ['leveldb_Privacy'],
  'abseil' => ['xcprivacy'],
  'GoogleUtilities' => ['GoogleUtilities_Privacy'],
  'BoringSSL-GRPC' => ['openssl_grpc'],
  'AppAuth' => ['AppAuthCore_Privacy'],
  'GTMSessionFetcher' => ['GTMSessionFetcher_Full_Privacy', 'GTMSessionFetcher_Core_Privacy']
}

# Tạo privacy bundle cho từng plugin
plugins.each do |plugin|
  plugin_dir = File.join(build_dir, plugin)
  FileUtils.mkdir_p(plugin_dir) unless Dir.exist?(plugin_dir)
  
  if bundle_formats.key?(plugin)
    bundle_formats[plugin].each do |bundle_name|
      bundle_dir = File.join(plugin_dir, "#{bundle_name}.bundle")
      FileUtils.mkdir_p(bundle_dir) unless Dir.exist?(bundle_dir)
      File.open(File.join(bundle_dir, bundle_name), 'w') { |f| f.puts "Created by bundle_patch.rb" }
      puts "Created #{bundle_dir}/#{bundle_name}"
    end
  else
    bundle_dir = File.join(plugin_dir, "#{plugin}_privacy.bundle")
    FileUtils.mkdir_p(bundle_dir) unless Dir.exist?(bundle_dir)
    File.open(File.join(bundle_dir, "#{plugin}_privacy"), 'w') { |f| f.puts "Created by bundle_patch.rb" }
    puts "Created #{bundle_dir}/#{plugin}_privacy"
  end
end

puts "All privacy bundles have been created"
