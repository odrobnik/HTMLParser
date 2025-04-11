// swift-tools-version: 5.10
import PackageDescription

let package = Package(
	name: "HTMLParser",
	products: [
		.library(name: "HTMLParser", targets: ["HTMLParser"]),
	],
	targets: [
		.target(
			name: "HTMLParser",
			dependencies: ["CHTMLParser"]
		),
		.systemLibrary(
			name: "CHTMLParser",
			path: "Sources/CHTMLParser",
			pkgConfig: "libxml-2.0",
			providers: [
				.apt(["libxml2-dev"]),
				.yum(["libxml2-devel"])
			]
		),
		.testTarget(
			name: "HTMLParserTests",
			dependencies: ["HTMLParser"]
		)
	]
)
