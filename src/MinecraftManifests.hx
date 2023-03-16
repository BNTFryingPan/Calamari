package;

typedef MinecraftVersion = {
   id:String,
   type:String,
   url:String,
   time:String,
   releaseTime:String,
}

typedef ManifestLatest = {
   release:String,
   snapshot:String,
}

typedef VersionManifest = {
   latest:ManifestLatest,
   versions:Array<MinecraftVersion>,
}

typedef AssetIndex = {
   id:String,
   sha1:String,
   size:Int,
   totalSize:Int,
   url:String,
}

typedef JavaVersionRequirement = {
   component:String,
   majorVersion:Int,
}

typedef ManifestOSRule = {
   arch:Null<String>,
   name:Null<String>,
   version:Null<String>,
}

typedef ManifestFeatureRule = {
   is_demo_user:Null<Bool>,
}

typedef ManifestRule = {
   action:String,
   os:Null<ManifestOSRule>,
   features:Null<ManifestFeatureRule>,
}

typedef LibraryArtifact = {
   path:String,
   sha1:String,
   size:Int,
   url:String,
}

typedef LibraryRequirement = {
   downloads:{artifact:LibraryArtifact},
   name:String,
   rules:Null<Array<ManifestRule>>,
}

typedef VersionDownload = {
   sha1:String,
   size:Int,
   url:String,
}

typedef VersionData = {
   assetIndex:AssetIndex,
   assets:String,
   complianceLevel:Int,
   downloads:{
      client:VersionDownload, ?client_mappings:VersionDownload, ?server:VersionDownload, ?server_mappings:VersionDownload,
   },
   id:String,
   javaVersion:JavaVersionRequirement,
   libraries:Array<LibraryRequirement>,
   logging:{
      client:{
         argument:String, file:{
            id:String, sha1:String, size:Int, url:String
         }, type:String
      }
   },
   mainClass:String,
   minimumLauncherVersion:Int,
   releaseTime:String,
   time:String,
   type:String,
}
