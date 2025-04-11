// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "HTMLParser",
	products: [
		.library(
			name: "HTMLParser",
			targets: ["HTMLParser"]),
	],
	targets: [
		.target(
			name: "HTMLParser",
			dependencies: ["CHTMLParser"]),
		.target(
			name: "CHTMLParser",
			dependencies: {
				#if os(Linux)
				return [.systemLibrary(name: "libxml2", pkgConfig: "libxml-2.0", providers: [
					.apt(["libxml2-dev"]),
					.brew(["libxml2"])
				])]
				#else
				return []
				#endif
			}(),
			path: "Sources/CHTMLParser",
			publicHeadersPath: "include"
		),
		.testTarget(
			name: "HTMLParserTests",
			dependencies: ["HTMLParser"]),
	]
)
