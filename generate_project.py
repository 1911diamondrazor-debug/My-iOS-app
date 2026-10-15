#!/usr/bin/env python3
"""Generate an Xcode project and a tiny public-format Core ML model. No dependencies."""
from pathlib import Path
import hashlib, json, struct, plistlib
ROOT = Path(__file__).resolve().parents[1]

def varint(n):
    out = bytearray()
    while n > 127: out.append((n & 127) | 128); n >>= 7
    out.append(n)
    return bytes(out)
def message(field, payload): return varint(field << 3 | 2) + varint(len(payload)) + payload
def string(field, value): return message(field, value.encode())
def feature(name): return string(1, name) + message(3, message(2, b''))
# Apple Core ML specification v1: Model.description.output is field 10, not 2.
description = message(1, feature('x')) + message(10, feature('y')) + string(11, 'y')
weights = message(1, struct.pack('<d', 2.0))
glm = message(1, weights) + message(2, struct.pack('<d', 0.1))
model = varint(1 << 3) + varint(1) + message(2, description) + message(300, glm)
(ROOT/'MLLab/Resources/TinyRegressor.mlmodel').write_bytes(model)

def ident(s): return hashlib.sha256(s.encode()).hexdigest()[:24].upper()
def q(s): return json.dumps(str(s))
objects = {}
def obj(key, value):
    uid = ident(key); objects[uid] = value; return uid
sources = sorted((ROOT/'MLLab').rglob('*.swift'))
sourceRefs = []; sourceBuilds = []
for path in sources:
    rel = path.relative_to(ROOT).as_posix()
    ref = obj(rel, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(rel)}; sourceTree = "<group>";')
    sourceRefs.append(ref)
    sourceBuilds.append(obj('build:'+rel, f'isa = PBXBuildFile; fileRef = {ref};'))
# Deliberately copy raw model bytes. Compile at runtime; no generated model class needed.
resourceRefs = []; resourceBuilds = []
for rel, typ in [('MLLab/Resources/TinyRegressor.mlmodel','file'), ('MLLab/Resources/Assets.xcassets','folder.assetcatalog')]:
    ref = obj(rel, f'isa = PBXFileReference; lastKnownFileType = {typ}; path = {q(rel)}; sourceTree = "<group>";')
    resourceRefs.append(ref); resourceBuilds.append(obj('build:'+rel, f'isa = PBXBuildFile; fileRef = {ref};'))
infoRef = obj('info', 'isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = MLLab/Info.plist; sourceTree = "<group>";')
product = obj('product','isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = MLLab.app; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products',f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
group = obj('mainGroup',f'isa = PBXGroup; children = ({",".join(sourceRefs+resourceRefs+[infoRef,products])},); sourceTree = "<group>";')
sourcePhase = obj('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(sourceBuilds)},); runOnlyForDeploymentPostprocessing = 0;')
resourcePhase = obj('resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(resourceBuilds)},); runOnlyForDeploymentPostprocessing = 0;')
frameworkPhase = obj('frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
def config(name, target):
    settings = {
        'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'27.0','SWIFT_VERSION':'5.0',
        'CLANG_ENABLE_MODULES':'YES','SWIFT_STRICT_CONCURRENCY':'targeted',
        'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if name=='Debug' else '-O',
        'DEBUG_INFORMATION_FORMAT':'dwarf' if name=='Debug' else 'dwarf-with-dsym',
    }
    if target: settings.update({'PRODUCT_BUNDLE_IDENTIFIER':'com.example.MLLab','PRODUCT_NAME':'$(TARGET_NAME)',
        'INFOPLIST_FILE':'MLLab/Info.plist','GENERATE_INFOPLIST_FILE':'NO','CODE_SIGN_STYLE':'Automatic',
        'TARGETED_DEVICE_FAMILY':'1,2','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator',
        'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','MARKETING_VERSION':'1.0','CURRENT_PROJECT_VERSION':'1',
        'SWIFT_EMIT_LOC_STRINGS':'YES'})
    if name=='Debug': settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG'
    body = ' '.join(f'{k} = {q(v)};' for k,v in settings.items())
    return obj(f'config:{target}:{name}',f'isa = XCBuildConfiguration; buildSettings = {{{body}}}; name = {name};')
def configs(target):
    ids=[config(n,target) for n in ['Debug','Release']]
    return obj(f'configs:{target}',f'isa = XCConfigurationList; buildConfigurations = ({",".join(ids)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
targetConfig = configs(True); projectConfig = configs(False)
target = obj('target',f'isa = PBXNativeTarget; buildConfigurationList = {targetConfig}; buildPhases = ({sourcePhase},{frameworkPhase},{resourcePhase},); buildRules = (); dependencies = (); name = MLLab; productName = MLLab; productReference = {product}; productType = "com.apple.product-type.application";')
project = obj('project',f'isa = PBXProject; attributes = {{LastSwiftUpdateCheck = 2700; LastUpgradeCheck = 2700;}}; buildConfigurationList = {projectConfig}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base,); mainGroup = {group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
pbx = '// !$*UTF8*$!\n{\n archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'
pbx += '\n'.join(f'{uid} = {{{body}}};' for uid,body in objects.items())
pbx += f'\n}}; rootObject = {project};\n}}\n'
(ROOT/'MLLab.xcodeproj/project.pbxproj').write_text(pbx)
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="MLLab.app" BlueprintName="MLLab" ReferencedContainer="container:MLLab.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="MLLab.app" BlueprintName="MLLab" ReferencedContainer="container:MLLab.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="MLLab.app" BlueprintName="MLLab" ReferencedContainer="container:MLLab.xcodeproj"/></BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(ROOT/'MLLab.xcodeproj/xcshareddata/xcschemes/MLLab.xcscheme').write_text(scheme)
info = {'CFBundleDisplayName':'ML Lab','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)',
'CFBundleName':'$(PRODUCT_NAME)','CFBundlePackageType':'APPL','CFBundleShortVersionString':'$(MARKETING_VERSION)',
'CFBundleVersion':'$(CURRENT_PROJECT_VERSION)','LSRequiresIPhoneOS':True,'UILaunchScreen':{},
'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False},
'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],
'UISupportedInterfaceOrientations~ipad':['UIInterfaceOrientationPortrait','UIInterfaceOrientationPortraitUpsideDown','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],
'NSCameraUsageDescription':'Track a body skeleton in the ARKit demonstration you start.',
'NSMicrophoneUsageDescription':'Record a short clip for local speech and sound analysis.',
'NSSpeechRecognitionUsageDescription':'Transcribe your selected or recorded audio in the speech demonstration.'}
with (ROOT/'MLLab/Info.plist').open('wb') as f: plistlib.dump(info,f)
print(f'Generated project: {len(sources)} Swift files; model: {len(model)} bytes.')
