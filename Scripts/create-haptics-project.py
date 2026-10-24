from pathlib import Path
import hashlib,plistlib
root=Path(__file__).resolve().parents[1];base=root/'Companion';project=base/'GhostHandsHaptics.xcodeproj';(project/'xcshareddata/xcschemes').mkdir(parents=True,exist_ok=True)
def uid(s):return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
objects=[]
def obj(name,body):objects.append(f'{uid(name)} = {{ {body} }};');return uid(name)
refs=[];products=[];targets=[]
for name,platform,family,bundle,files in [
 ('GhostHandsWatch','watchos','4','com.calebwieman.ghosthands.haptics.watchkitapp',['Watch/WatchApp.swift','../GhostHands/HapticProtocol.swift']),
 ('GhostHandsHaptics','iphoneos','1','com.calebwieman.ghosthands.haptics',['Phone/PhoneApp.swift','../GhostHands/HapticProtocol.swift','../GhostHands/HapticNearby.swift'])]:
 builds=[]
 for file in files:
  ref=obj(name+file+'ref',f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{file}"; sourceTree = "<group>";');refs.append(ref)
  builds.append(obj(name+file+'build',f'isa = PBXBuildFile; fileRef = {ref};'))
 product=obj(name+'product',f'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {name}.app; sourceTree = BUILT_PRODUCTS_DIR;');products.append(product)
 sources=obj(name+'sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)},); runOnlyForDeploymentPostprocessing = 0;')
 frameworks=obj(name+'frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
 resources=obj(name+'resources','isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
 phases=[sources,frameworks,resources];dependencies=[]
 if platform=='iphoneos':
  embed=obj('embedwatchbuild',f'isa = PBXBuildFile; fileRef = {uid("GhostHandsWatchproduct")}; settings = {{ ATTRIBUTES = (RemoveHeadersOnCopy,); }};')
  phases.append(obj('embedwatch',f'isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = "$(CONTENTS_FOLDER_PATH)/Watch"; dstSubfolderSpec = 16; files = ({embed},); name = "Embed Watch Content"; runOnlyForDeploymentPostprocessing = 0;'))
  proxy=obj('watchproxy',f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("GhostHandsWatchtarget")}; remoteInfo = GhostHandsWatch;')
  dependencies.append(obj('watchdependency',f'isa = PBXTargetDependency; target = {uid("GhostHandsWatchtarget")}; targetProxy = {proxy};'))
 configs=[]
 for mode in ['Debug','Release']:
  settings=f'SDKROOT = {platform}; SUPPORTED_PLATFORMS = "'+('watchos watchsimulator' if platform=='watchos' else 'iphoneos iphonesimulator')+'"; '+('WATCHOS_DEPLOYMENT_TARGET = 10.0; SKIP_INSTALL = YES; ' if platform=='watchos' else 'IPHONEOS_DEPLOYMENT_TARGET = 17.0; ')
  settings+=f'TARGETED_DEVICE_FAMILY = {family}; PRODUCT_BUNDLE_IDENTIFIER = {bundle}; PRODUCT_NAME = "$(TARGET_NAME)"; INFOPLIST_FILE = '+('Watch' if platform=='watchos' else 'Phone')+'/Info.plist; GENERATE_INFOPLIST_FILE = NO; CODE_SIGN_STYLE = Automatic; DEVELOPMENT_TEAM = J9YA9D6669; CURRENT_PROJECT_VERSION = 16; MARKETING_VERSION = 1.0; SWIFT_VERSION = 5.0; CLANG_ENABLE_MODULES = YES; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks"; SWIFT_OPTIMIZATION_LEVEL = "'+('-Onone' if mode=='Debug' else '-O')+'";'
  configs.append(obj(name+mode,f'isa = XCBuildConfiguration; name = {mode}; buildSettings = {{ {settings} }};'))
 configlist=obj(name+'configs',f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
 target=obj(name+'target',f'isa = PBXNativeTarget; buildConfigurationList = {configlist}; buildPhases = ({",".join(phases)},); buildRules = (); dependencies = ({",".join(dependencies)}); name = {name}; productName = {name}; productReference = {product}; productType = "com.apple.product-type.application";');targets.append(target)
 info={'CFBundleDevelopmentRegion':'en','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)','CFBundlePackageType':'APPL','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)','CFBundleDisplayName':'GhostHands Haptics'}
 if platform=='watchos':info.update(WKApplication=True,WKCompanionAppBundleIdentifier='com.calebwieman.ghosthands.haptics',UISupportedInterfaceOrientations=['UIInterfaceOrientationPortrait','UIInterfaceOrientationPortraitUpsideDown'])
 else:info.update(NSLocalNetworkUsageDescription='Connect to GhostHands on Vision Pro and relay optional button haptics to your paired Watch.',NSBonjourServices=['_gh-haptics._tcp'],UILaunchScreen={},UISupportedInterfaceOrientations=['UIInterfaceOrientationPortrait'],UIApplicationSceneManifest={'UIApplicationSupportsMultipleScenes':False})
 (base/('Watch' if platform=='watchos' else 'Phone')/'Info.plist').write_bytes(plistlib.dumps(info))
 (project/'xcshareddata/xcschemes'/f'{name}.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{name}.app" BlueprintName="{name}" ReferencedContainer="container:GhostHandsHaptics.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{name}.app" BlueprintName="{name}" ReferencedContainer="container:GhostHandsHaptics.xcodeproj"/></BuildableProductRunnable></LaunchAction><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
productgroup=obj('products',f'isa = PBXGroup; children = ({",".join(products)},); name = Products; sourceTree = "<group>";')
main=obj('main',f'isa = PBXGroup; children = ({",".join(refs)},{productgroup},); sourceTree = "<group>";')
configs=[]
for mode in ['Debug','Release']:configs.append(obj('project'+mode,f'isa = XCBuildConfiguration; name = {mode}; buildSettings = {{ SWIFT_VERSION = 5.0; CLANG_ENABLE_MODULES = YES; }};'))
cl=obj('projectconfigs',f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
p=obj('project',f'isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700;}}; buildConfigurationList = {cl}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base,); mainGroup = {main}; productRefGroup = {productgroup}; projectDirPath = ""; projectRoot = ""; targets = ({",".join(targets)},);')
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {p}; }}\n')
