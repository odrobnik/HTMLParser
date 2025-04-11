// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "HTMLParser",
	platforms: [
		.macOS(.v10_15),
		.iOS(.v13)
	],
	products: [
		.library(name: "HTMLParser", targets: ["HTMLParser"]),
	],
	targets: [
		.systemLibrary(
			name: "CLibXML2",
			path: "Sources/CLibXML2",
			pkgConfig: "libxml-2.0",
			providers: [
				.apt(["libxml2-dev"]),
				.yum(["libxml2-devel"])
			]
		),
		.target(
		  name: "CHTMLParser",
		  dependencies: ["CLibXML2"],
		  path: "Sources/CHTMLParser",
		  publicHeadersPath: "include",
		  cSettings: [
			.headerSearchPath("include"),
			.headerSearchPath("../../CLibXML2")
		  ],
		  linkerSettings: [
			.linkedLibrary("xml2")
		  ]
		),

		// Your Swift interface
		.target(
			name: "HTMLParser",
			dependencies: ["CHTMLParser"]
		),

		// Tests
		.testTarget(
			name: "HTMLParserTests",
			dependencies: ["HTMLParser"]
		)
	]
)
