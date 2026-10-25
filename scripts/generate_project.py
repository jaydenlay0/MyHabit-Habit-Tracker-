#!/usr/bin/env python3
"""Generate the checked-in Xcode project using only Python's standard library."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parent.parent
objects = {}
def uid(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def add(key, body):
    identifier = uid(key); objects[identifier] = body; return identifier
def q(s): return '"' + str(s).replace('\\', '\\\\').replace('"', '\\"') + '"'
def arr(items): return '(' + ', '.join(items) + (',' if items else '') + ')'
def settings(values): return '{' + ''.join(f'{k} = {q(v)}; ' for k,v in values.items()) + '}'
files = {}
for directory in ['Shared', 'MyHabits', 'MyHabitsWidget', 'MyHabitsTests']:
    for path in sorted((root/directory).iterdir()):
        if path.is_file():
            relative = str(path.relative_to(root))
            kind = {'.swift':'sourcecode.swift', '.plist':'text.plist.xml', '.entitlements':'text.plist.entitlements', '.xcprivacy':'text.xml'}.get(path.suffix, 'text')
            files[relative] = add('file:'+relative, f'isa = PBXFileReference; lastKnownFileType = {kind}; path = {q(relative)}; sourceTree = "<group>";')
products = {}
for name, ext, kind in [('MyHabits','app','wrapper.application'),('MyHabitsWidget','appex','wrapper.app-extension'),('MyHabitsTests','xctest','wrapper.cfbundle')]:
    products[name] = add('product:'+name, f'isa = PBXFileReference; explicitFileType = {kind}; path = {name}.{ext}; sourceTree = BUILT_PRODUCTS_DIR;')
product_group = add('products', f'isa = PBXGroup; children = {arr(list(products.values()))}; name = Products; sourceTree = "<group>";')
main_group = add('main', f'isa = PBXGroup; children = {arr(list(files.values())+[product_group])}; sourceTree = "<group>";')
project_id = uid('project')
targets = []
for name in products:
    selected = [p for p in files if p.endswith('.swift') and (p.startswith(name+'/') or (name != 'MyHabitsTests' and p.startswith('Shared/')) or (name == 'MyHabitsWidget' and p == 'MyHabits/Theme.swift'))]
    builds = [add('build:'+name+':'+p, f'isa = PBXBuildFile; fileRef = {files[p]};') for p in selected]
    sources = add('sources:'+name, f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(builds)}; runOnlyForDeploymentPostprocessing = 0;')
    frameworks = add('frameworks:'+name, 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    resource_builds = []
    if name != 'MyHabitsTests':
        resource_builds.append(add('privacy:'+name, f'isa = PBXBuildFile; fileRef = {files["MyHabits/PrivacyInfo.xcprivacy"]};'))
    resources = add('resources:'+name, f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {arr(resource_builds)}; runOnlyForDeploymentPostprocessing = 0;')
    phases = [sources, frameworks, resources]; dependencies = []
    dependency = 'MyHabitsWidget' if name == 'MyHabits' else ('MyHabits' if name == 'MyHabitsTests' else None)
    if dependency:
        proxy = add('proxy:'+name, f'isa = PBXContainerItemProxy; containerPortal = {project_id}; proxyType = 1; remoteGlobalIDString = {uid("target:"+dependency)}; remoteInfo = {dependency};')
        dependencies.append(add('dependency:'+name, f'isa = PBXTargetDependency; target = {uid("target:"+dependency)}; targetProxy = {proxy};'))
    if name == 'MyHabits':
        embed_file = add('embed-widget', f'isa = PBXBuildFile; fileRef = {products["MyHabitsWidget"]}; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, );}};')
        phases.append(add('embed-phase', f'isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 13; files = ({embed_file}, ); name = "Embed App Extensions"; runOnlyForDeploymentPostprocessing = 0;'))
    configs = []
    for mode in ['Debug','Release']:
        values = dict(PRODUCT_NAME='$(TARGET_NAME)', PRODUCT_BUNDLE_IDENTIFIER='com.example.'+name, GENERATE_INFOPLIST_FILE='YES', MARKETING_VERSION='1.0', CURRENT_PROJECT_VERSION='1', SWIFT_VERSION='5.0', IPHONEOS_DEPLOYMENT_TARGET='17.0', TARGETED_DEVICE_FAMILY='1,2', CODE_SIGN_STYLE='Automatic', SWIFT_EMIT_LOC_STRINGS='YES')
        if name != 'MyHabitsTests': values['CODE_SIGN_ENTITLEMENTS'] = name+'/'+name+'.entitlements'
        if name == 'MyHabits':
            values.update(INFOPLIST_KEY_CFBundleDisplayName='MyHabits', INFOPLIST_KEY_UILaunchScreen_Generation='YES', INFOPLIST_KEY_UIApplicationSceneManifest_Generation='YES', INFOPLIST_KEY_UISupportedInterfaceOrientations='UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight')
        if name == 'MyHabitsWidget': values.update(INFOPLIST_FILE='MyHabitsWidget/Info.plist', SKIP_INSTALL='YES', APPLICATION_EXTENSION_API_ONLY='YES', PRODUCT_BUNDLE_IDENTIFIER='com.example.MyHabits.widget')
        if name == 'MyHabitsTests': values.update(TEST_HOST='$(BUILT_PRODUCTS_DIR)/MyHabits.app/MyHabits', BUNDLE_LOADER='$(TEST_HOST)')
        configs.append(add('config:'+name+mode, f'isa = XCBuildConfiguration; buildSettings = {settings(values)}; name = {mode};'))
    config_list = add('configs:'+name, f'isa = XCConfigurationList; buildConfigurations = {arr(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    product_type = {'MyHabits':'application','MyHabitsWidget':'app-extension','MyHabitsTests':'bundle.unit-test'}[name]
    targets.append(add('target:'+name, f'isa = PBXNativeTarget; buildConfigurationList = {config_list}; buildPhases = {arr(phases)}; buildRules = (); dependencies = {arr(dependencies)}; name = {name}; productName = {name}; productReference = {products[name]}; productType = "com.apple.product-type.{product_type}";'))
configs=[]
for mode in ['Debug','Release']:
    values = dict(SDKROOT='iphoneos', CLANG_ENABLE_MODULES='YES', CLANG_ENABLE_OBJC_ARC='YES', SWIFT_OPTIMIZATION_LEVEL='-Onone' if mode == 'Debug' else '-O', ENABLE_TESTABILITY='YES' if mode == 'Debug' else 'NO', DEBUG_INFORMATION_FORMAT='dwarf' if mode == 'Debug' else 'dwarf-with-dsym')
    configs.append(add('project-config:'+mode, f'isa = XCBuildConfiguration; buildSettings = {settings(values)}; name = {mode};'))
config_list=add('project-configs', f'isa = XCConfigurationList; buildConfigurations = {arr(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
add('project', f'isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; }}; buildConfigurationList = {config_list}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main_group}; productRefGroup = {product_group}; projectDirPath = ""; projectRoot = ""; targets = {arr(targets)};')
(root/'MyHabits.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(f'{key} = {{{body}}};' for key,body in objects.items())+f'\n}}; rootObject = {project_id}; }}\n')
def ref(name): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target:"+name)}" BuildableName="{name}.{"app" if name=="MyHabits" else "xctest"}" BlueprintName="{name}" ReferencedContainer="container:MyHabits.xcodeproj"/>'
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref('MyHabits')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref('MyHabitsTests')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('MyHabits')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('MyHabits')}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(root/'MyHabits.xcodeproj/xcshareddata/xcschemes/MyHabits.xcscheme').write_text(scheme)
print('Generated project and shared MyHabits scheme.')
