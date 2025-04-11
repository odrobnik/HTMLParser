// swift-tools-version: 5.10
import PackageDescription

let package = Package(
	name: "HTMLParser",
	products: [
		.library(name: "HTMLParser", targets: ["HTMLParser"]),
	],
	targets: [
	  .target(
		name: "CHTMLParser",
		dependencies: [],
		path: "Sources/CHTMLParser",
		publicHeadersPath: "include",
		cSettings: [
		  .headerSearchPath("include")
		],
		linkerSettings: [
		  .linkedLibrary("xml2")
		]
	  ),
	  .target(
		name: "HTMLParser",
		dependencies: ["CHTMLParser"]
	  ),
	  .testTarget(
		name: "HTMLParserTests",
		dependencies: ["HTMLParser"]
	  )
	]
)
