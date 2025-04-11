// swift-tools-version:5.10
import PackageDescription

let package = Package(
	name: "HTMLParser",
	products: [
		.library(name: "HTMLParser", targets: ["HTMLParser"]),
	],
	targets: [
		// System module for libxml2
		.systemLibrary(
			name: "CLibXML2",
			path: "Sources/CLibXML2",
			pkgConfig: "libxml-2.0",
			providers: [
				.apt(["libxml2-dev"]),
				.yum(["libxml2-devel"])
			]
		),

		// Your C target
		.target(
			name: "CHTMLParser",
			dependencies: ["CLibXML2"],
			path: "Sources/CHTMLParser",
			publicHeadersPath: "include",
			cSettings: [
				.headerSearchPath("include"),
				.headerSearchPath("../CLibXML2")
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
