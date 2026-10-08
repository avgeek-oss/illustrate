import XCTest
@testable import Illustrate

final class CSVParserTests: XCTestCase {
    // MARK: - Basic Parsing

    func testParse_PromptOnly() {
        let csv = """
        prompt
        A cat sitting on a windowsill
        A dog playing in the park
        """
        let result = CSVParser.parse(csv)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].prompt, "A cat sitting on a windowsill")
        XCTAssertNil(result[0].filename)
        XCTAssertEqual(result[1].prompt, "A dog playing in the park")
        XCTAssertNil(result[1].filename)
    }

    func testParse_PromptAndFilename() {
        let csv = """
        filename,prompt
        cat,A cat sitting on a windowsill
        dog,A dog playing in the park
        """
        let result = CSVParser.parse(csv)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].filename, "cat")
        XCTAssertEqual(result[0].prompt, "A cat sitting on a windowsill")
        XCTAssertEqual(result[1].filename, "dog")
        XCTAssertEqual(result[1].prompt, "A dog playing in the park")
    }

    func testParse_FilenameAndPromptReversed() {
        let csv = """
        prompt,filename
        A cat sitting on a windowsill,cat
        A dog playing in the park,dog
        """
        let result = CSVParser.parse(csv)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].prompt, "A cat sitting on a windowsill")
        XCTAssertEqual(result[0].filename, "cat")
        XCTAssertEqual(result[1].prompt, "A dog playing in the park")
        XCTAssertEqual(result[1].filename, "dog")
    }

    // MARK: - Empty / Missing Data

    func testParse_EmptyContent() {
        let result = CSVParser.parse("")
        XCTAssertTrue(result.isEmpty)
    }

    func testParse_HeaderOnly() {
        let csv = "prompt\n"
        let result = CSVParser.parse(csv)
        XCTAssertTrue(result.isEmpty)
    }

    func testParse_NoPromptHeader() {
        let csv = """
        name,description
        Cat,Meowing animal
        """
        let result = CSVParser.parse(csv)
        XCTAssertTrue(result.isEmpty)
    }

    func testParse_EmptyPromptSkipped() {
        let csv = """
        prompt
        A valid prompt

        Another valid prompt
        """
        let result = CSVParser.parse(csv)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].prompt, "A valid prompt")
        XCTAssertEqual(result[1].prompt, "Another valid prompt")
    }

    func testParse_OptionalFilename_Mixed() {
        let csv = """
        filename,prompt
        cat,A cat
        ,A dog
        bird,A bird
        """
        let result = CSVParser.parse(csv)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].filename, "cat")
        XCTAssertNil(result[1].filename)
        XCTAssertEqual(result[2].filename, "bird")
    }

    // MARK: - Quoted Fields

    func testParse_QuotedPromptWithComma() {
        let csv = """
        prompt
        "A cat, sitting on a windowsill, in the sun"
        """
        let result = CSVParser.parse(csv)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].prompt, "A cat, sitting on a windowsill, in the sun")
    }

    func testParse_QuotedPromptWithNewline() {
        let csv = "prompt\n\"A cat sitting\non a windowsill\"\n"
        let result = CSVParser.parse(csv)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].prompt, "A cat sitting\non a windowsill")
    }

    func testParse_QuotedPromptWithMultipleNewlines() {
        let csv = "prompt\n\"Line one\n\nLine two\n\nLine three\"\n"
        let result = CSVParser.parse(csv)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].prompt, "Line one\n\nLine two\n\nLine three")
    }

    func testParse_EscapedQuotes() {
        let csv = """
        prompt
        "He said ""hello"" to me"
        """
        let result = CSVParser.parse(csv)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].prompt, "He said \"hello\" to me")
    }

    func testParse_QuotedFilenameAndPrompt() {
        let csv = """
        filename,prompt
        "my cat","A cat sitting on a windowsill"
        """
        let result = CSVParser.parse(csv)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].filename, "my cat")
        XCTAssertEqual(result[0].prompt, "A cat sitting on a windowsill")
    }

    // MARK: - Line Ending Variations

    func testParse_CRLF() {
        let csv = "prompt\r\ncat prompt\r\ndog prompt\r\n"
        let result = CSVParser.parse(csv)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].prompt, "cat prompt")
        XCTAssertEqual(result[1].prompt, "dog prompt")
    }

    func testParse_CR() {
        let csv = "prompt\rcat prompt\rdog prompt\r"
        let result = CSVParser.parse(csv)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].prompt, "cat prompt")
        XCTAssertEqual(result[1].prompt, "dog prompt")
    }

    func testParse_MixedLineEndings() {
        let csv = "prompt\r\ncat prompt\ndog prompt\r\nbird prompt"
        let result = CSVParser.parse(csv)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].prompt, "cat prompt")
        XCTAssertEqual(result[1].prompt, "dog prompt")
        XCTAssertEqual(result[2].prompt, "bird prompt")
    }

    // MARK: - BOM

    func testParse_BOMStripped() {
        let csv = "\u{FEFF}prompt\ncat prompt\n"
        let result = CSVParser.parse(csv)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].prompt, "cat prompt")
    }

    // MARK: - Real-World Multi-line Prompt

    func testParse_LongMultiLineQuotedPrompts() {
        let csv = """
        filename,prompt
        Dashboard,"Create a minimal 2D Risograph-style cover image.

        The hero object should be a single physical object made from one thick matte sheet.

        Keep the style flat and editorial."
        Agent Builder,"Create a modular assembly kit.

        Inside the object, include interlocking forms.

        No text, no letters, no numbers."
        """
        let result = CSVParser.parse(csv)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].filename, "Dashboard")
        XCTAssertTrue(result[0].prompt.contains("single physical object"))
        XCTAssertTrue(result[0].prompt.contains("flat and editorial"))
        XCTAssertEqual(result[1].filename, "Agent Builder")
        XCTAssertTrue(result[1].prompt.contains("interlocking forms"))
    }

    func testParse_TemplateCSV() {
        let csv = """
        prompt,filename
        A serene mountain landscape at sunset with golden light,mountain_sunset
        A futuristic city skyline with flying cars,futuristic_city
        A cozy coffee shop interior with warm lighting,coffee_shop
        An underwater scene with colorful coral reef,coral_reef
        A magical forest with glowing mushrooms at night,
        """
        let result = CSVParser.parse(csv)
        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(result[0].filename, "mountain_sunset")
        XCTAssertNil(result[4].filename)
    }

    // MARK: - parseRows

    func testParseRows_SimpleCSV() {
        let csv = "a,b,c\n1,2,3\n4,5,6\n"
        let rows = CSVParser.parseRows(csv)
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0], ["a", "b", "c"])
        XCTAssertEqual(rows[1], ["1", "2", "3"])
        XCTAssertEqual(rows[2], ["4", "5", "6"])
    }

    func testParseRows_QuotedFieldWithComma() {
        let csv = "name,desc\n\"hello, world\",test\n"
        let rows = CSVParser.parseRows(csv)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1][0], "hello, world")
    }

    func testParseRows_TrailingNewlineOmitsEmptyRow() {
        let csv = "a,b\n1,2\n"
        let rows = CSVParser.parseRows(csv)
        XCTAssertEqual(rows.count, 2)
    }
}
