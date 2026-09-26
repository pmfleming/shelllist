pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Ui as Ui

TestCase {
    id: testCase
    name: "DetailLayout"
    when: windowShown
    visible: true
    width: 700
    height: 500

    Component {
        id: pageFactory
        Ui.DetailFlickable {
            width: 320
            height: 180
            property alias message: message
            property alias footer: footer

            Rectangle {
                width: parent.width
                height: 40
            }
            Ui.CenteredMessage {
                id: message
                width: parent.width
                height: Math.max(120, implicitHeight)
                text: "No additional actions"
            }
            Rectangle {
                id: footer
                width: parent.width
                height: 50
            }
        }
    }

    function init() {
        failOnWarning(/.*/);
    }

    function test_columnStateTransitionsAndWrapping() {
        const page = createTemporaryObject(pageFactory, testCase);
        verify(page !== null);
        for (const width of [320, 180, 675]) {
            page.width = width;
            page.message.text = "An application with a long name has no additional actions. ".repeat(8);
            for (const visible of [true, false, true]) {
                page.message.visible = visible;
                tryCompare(page.footer, "y", 40 + page.cardSpacing + (visible ? page.message.height + page.cardSpacing : 0));
                tryCompare(page, "contentHeight", page.footer.y + page.footer.height);
                compare(page.interactive, page.contentHeight > page.height);
                if (visible) {
                    verify(page.message.height >= page.message.implicitHeight);
                    verify(page.message.contentWidth <= width + 1, "long messages wrap to the column width");
                }
            }
        }
        page.message.visible = false;
        tryCompare(page, "contentHeight", 90 + page.cardSpacing);
        verify(!page.interactive, "short content must stop scrolling");
    }
}
