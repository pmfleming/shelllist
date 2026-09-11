pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Launcher as Launcher

TestCase {
    id: testCase
    name: "ApplicationPageLayout"
    when: windowShown
    visible: true
    width: 700
    height: 500

    Component {
        id: pageFactory
        Launcher.ApplicationPage {
            width: 675
            height: 220
            uiScale: 1
            actionHeight: 36
            application: ({})
            controller: Launcher.ApplicationController {}
        }
    }

    function init() {
        failOnWarning(/.*/);
    }

    function application(instanceCount, actionCount, comment) {
        return {
            name: "Firefox",
            kind: "desktop-application",
            comment: comment,
            instances: Array.from({
                length: instanceCount
            }, function (_, index) {
                return {
                    title: "Window " + index,
                    workspace_name: "2",
                    focused: index === 0
                };
            }),
            desktop_actions: Array.from({
                length: actionCount
            }, function (_, index) {
                return {
                    name: "Application action " + index
                };
            })
        };
    }

    function verifyStack(page) {
        tryVerify(function () {
            let bottom = 0;
            let count = 0;
            for (const item of page.cards) {
                if (!item.visible || item.height <= 0 || item.width <= 0)
                    continue;
                const expectedY = bottom + (count > 0 ? page.cardSpacing : 0);
                if (Math.abs(item.y - expectedY) > 1)
                    return false;
                bottom = item.y + item.height;
                ++count;
            }
            return count > 0 && Math.abs(page.contentHeight - bottom) <= 1;
        }, 1000, "visible sections must stack without overlap and determine the scrolling extent");
    }

    function test_emptyPopulatedAndSelectionTransitions() {
        const page = createTemporaryObject(pageFactory, testCase);
        verify(page !== null);
        verifyStack(page);
        for (const width of [675, 320]) {
            page.width = width;
            for (const counts of [[1, 3], [0, 0], [0, 3], [4, 0], [4, 3], [0, 0], [1, 3]]) {
                page.application = application(counts[0], counts[1], "Web browser with a description that wraps on narrow panels. ".repeat(2));
                verifyStack(page);
                compare(page.interactive, page.contentHeight > page.height);
                const instances = page.cards[1];
                const actions = page.cards[2];
                if (counts[0] && counts[1])
                    verify(actions.y >= instances.y + instances.height + page.cardSpacing);
                page.visible = false;
                page.application = application(counts[0], counts[1], "");
                page.visible = true;
                verifyStack(page);
            }
        }
    }

    function test_contentCanShrinkAfterScrolling() {
        const page = createTemporaryObject(pageFactory, testCase);
        page.application = application(8, 3, "");
        verifyStack(page);
        verify(page.interactive);
        page.contentY = page.contentHeight - page.height;
        page.application = application(0, 0, "");
        verifyStack(page);
        verify(!page.interactive);
        tryCompare(page, "contentY", 0);
    }
}
