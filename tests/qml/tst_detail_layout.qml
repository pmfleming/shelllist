pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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

    Component {
        id: cardFactory
        Ui.DetailColumnCard {
            width: 320
            title: "Services"
            height: Math.max(110, implicitHeight)
            property alias message: message

            Ui.ThemeText {
                id: message
                Layout.fillWidth: true
                text: "A long service description that wraps inside a content-sized card. ".repeat(12)
                wrapMode: Text.Wrap
            }
        }
    }

    Component {
        id: tabFactory
        Ui.TabbedDetailsStack {
            id: tabs
            width: 320
            height: 240
            footerHeight: 40
            selectedValue: "empty"
            tabs: [
                {
                    value: "empty",
                    label: "Empty"
                },
                {
                    value: "content",
                    label: "Content"
                }
            ]
            property alias loader: loader

            Loader {
                id: loader
                anchors.fill: parent
                asynchronous: true
                sourceComponent: tabs.selectedValue === "empty" ? emptyFactory : pageFactory
            }
            Component {
                id: emptyFactory
                Ui.CenteredMessage {
                    text: "Weather is not configured for this city"
                }
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

    function test_contentSizedCardsAndHiddenHeadings() {
        const card = createTemporaryObject(cardFactory, testCase);
        verify(card !== null);
        for (const title of ["Services", "", "A very long translated heading ".repeat(5)]) {
            card.title = title;
            for (const width of [320, 180, 675]) {
                card.width = width;
                tryCompare(card.message, "width", width - 2 * card.contentPadding);
                tryCompare(card, "height", Math.max(110, card.implicitHeight));
                tryCompare(card.message.parent, "height", card.height - 2 * card.verticalContentPadding - card.headingHeight - card.headingSpacing);
                tryVerify(function () {
                    return card.message.height >= card.message.implicitHeight;
                });
                if (title === "") {
                    compare(card.headingHeight, 0);
                    compare(card.headingSpacing, 0);
                }
                tryVerify(function () {
                    return card.message.mapToItem(card, 0, card.message.height).y <= card.height - card.verticalContentPadding + 1;
                });
            }
        }
    }

    function test_loaderTabsOwnBoundsAndKeepFooterOutsideContent() {
        const tabs = createTemporaryObject(tabFactory, testCase);
        verify(tabs !== null);
        for (const height of [240, 140, 500]) {
            tabs.height = height;
            for (const selection of ["empty", "content", "empty"]) {
                tabs.selectedValue = selection;
                tryCompare(tabs.loader, "status", Loader.Ready);
                const item = tabs.loader.item;
                tryCompare(item, "width", tabs.width);
                tryCompare(item, "height", height - tabs.footerHeight - tabs.sectionSpacing);
                compare(item.x, 0);
                compare(item.y, 0);
                verify(item.mapToItem(tabs, 0, item.height).y <= height - tabs.footerHeight - tabs.sectionSpacing);
                if (selection === "empty") {
                    compare(item.horizontalAlignment, Text.AlignHCenter);
                    compare(item.verticalAlignment, Text.AlignVCenter);
                } else {
                    item.contentY = 50;
                    compare(tabs.loader.y, 0, "scrolling must not move the tab viewport");
                }
            }
        }
    }

}
