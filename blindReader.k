# Load some sounds to indicate what is going on
$internetAccessSoundRef ? Var = void.
!uiAudioPlayer ("/app/" + appId + "/resources/internet-access.mp3") {
    internetAccessSoundRef = x.
}.

# Where are we in the hierarchy?
$hierarchyLayers ? ModifiableList = ().  # Will be filled with lists
$indexesInHierarchyLayers ? ModifiableList = ().  # Will be filled with integers

$NO_LAYER_SUPPORT = 0. # If there is no layer (or layer item)
$LAYER_EMPTY = 1. # If there is a layer, but it is empty
$LAYER_OK = 2. # If there is a layer and it is not empty. Or if there is a layer item
$LAYER_CUSTOM = 3. # If the layer has custom behavior
$LAYER_CYCLE = 4. # If we went to the beginning or end

$goToNextLayerAsync = !fun ($then) {
    # Get the next layer from the hierarchy
    $currentLayer = last: getArray: hierarchyLayers.
    $getLayerAsync = $getLayerAsync propOf (last: getArray: indexesInHierarchyLayers) at currentLayer.
    
    !ifElse (void eq getLayerAsync) {
        # We do not have the option to go to a next layer
        then: NO_LAYER_SUPPORT.
    };{
        # Attempt to access the next layer
        getLayerAsync: ($layer ? (List:Any)) fun {
            # Does the layer have any content?
            !ifElse (0 eq length: layer) {
                # Layer is empty, but present
                then: LAYER_EMPTY.
            };{
                # Layer is present and has content
                # Navigate to it
                ($push propOf hierarchyLayers): [layer].
                ($push propOf indexesInHierarchyLayers): 0.
                then: LAYER_OK.
            }
        }.
    }
}.

$goToPreviousLayer = !fun () {
    # If needed, run a custom action of the previous item
    do: $onBeforePreviousLayer propOf print: !getCurrentLayerItem.
    
    $lengthOfList = length: getArray: hierarchyLayers.
    !ifElse (1 eq lengthOfList) {
        # There is no previous layer (we are in the root layer)
        `Return` NO_LAYER_SUPPORT
    };{
        # There is a previous layer; remove the current one from the list
        $indexToRemove = lengthOfList - 1.
        ($removeIndex propOf hierarchyLayers): indexToRemove.
        ($removeIndex propOf indexesInHierarchyLayers): indexToRemove.
        
        `Return` LAYER_OK
    }
}.

$goToPreviousLayerItem = !fun () {
    # Before we do anything: check if the layer item overrides the default behaviour
    $currentLayerItem = !getCurrentLayerItem.
    !ifElse (not: void eq $onPreviousLayerItem propOf currentLayerItem) {
        do: $onPreviousLayerItem propOf currentLayerItem.
        LAYER_CUSTOM
    };{
        $currentIndex = last: getArray: indexesInHierarchyLayers.
        !ifElse (0 eq currentIndex) {
            `Return` NO_LAYER_SUPPORT
        };{
            # We have a previous item!
            $indexOfCurrentLayer = (length: getArray: indexesInHierarchyLayers) - 1.
            indexOfCurrentLayer ($setIndex propOf indexesInHierarchyLayers) currentIndex - 1.

            `Return` LAYER_OK
        }
    }
}.

$goToNextLayerItem = !fun () {
    # Before we do anything: check if the layer item overrides the default behaviour
    $currentLayerItem = !getCurrentLayerItem.
    !ifElse (not: void eq $onNextLayerItem propOf currentLayerItem) {
        do: $onNextLayerItem propOf currentLayerItem.
        LAYER_CUSTOM
    };{
        # Do the default action
        $currentIndex = last: getArray: indexesInHierarchyLayers.
        $indexOfCurrentLayer = (length: getArray: indexesInHierarchyLayers) - 1.
        !ifElse (currentIndex eq (length: indexOfCurrentLayer at getArray: hierarchyLayers) - 1) {
            # Maybe we have to go back to the first item?
            !ifElse ($cycleItemsAfterLast propOf config) {
                # Go back to first
                indexOfCurrentLayer ($setIndex propOf indexesInHierarchyLayers) 0.
                `Return` LAYER_CYCLE
            };{
                `Return` NO_LAYER_SUPPORT
            }
        };{
            # We have a next item!
            indexOfCurrentLayer ($setIndex propOf indexesInHierarchyLayers) currentIndex + 1.
            
            `Return` LAYER_OK
        }
    }.
}.

$getCurrentLayerItem = !fun () {
    `Return` (last: getArray: indexesInHierarchyLayers) at last: getArray: hierarchyLayers.
}.

$LAYER_UP = 0.
$LAYER_DOWN = 1.
$LAYER_ITEM_UP = 2.
$LAYER_ITEM_DOWN = 3.

# layerStatus is one of LAYER_OK, LAYER_EMPTY or NO_LAYER_SUPPORT
# layerDirection is one of the values above
$getTextForLayerStatus = !fun ($layerStatus; $layerDirection) {
    ". " strJoin ;/ do each !switch layerStatus
        [{LAYER_EMPTY eq x}; {$layerEmptyMessage propOf config}];
        [{NO_LAYER_SUPPORT eq x}; () fun {
            do: first: !switchEq layerDirection
                [LAYER_UP; {$noLayerUpMessage propOf config}];
                [LAYER_ITEM_UP; {$noLayerItemUpMessage propOf config}];
                [LAYER_DOWN; {$noLayerDownMessage propOf config}];
                [LAYER_ITEM_DOWN; {$noLayerItemDownMessage propOf config}]
        }];
        [{LAYER_OK eq x}; {
            do: first: !switchEq layerDirection
                [LAYER_UP; {$previousLevelHint propOf config}];
                [LAYER_DOWN; {$nextLevelHint propOf config}]
        }];
        [{LAYER_CYCLE eq x}; {$backToFirstItemMessage propOf config}];
        [{(LAYER_OK eq x) | (NO_LAYER_SUPPORT eq x) | (LAYER_CYCLE eq x)}; {$title propOf !getCurrentLayerItem}].
}.

$getTextForLocationInHierarchy = !fun () {
    # Which parents?
    $indexes = getArray: indexesInHierarchyLayers.
    $text = "Du bist hier: " + (". Unterpunkt: " strJoin !each (getArray: hierarchyLayers) -> ($x; $index) fun {
        # print: x.
        $title propOf (index at indexes) at x
    }).
    
    `Return` text
}.

# Functions for accessing RSS feeds
$titledUrlsFromRssUrlAsync = !fun ($withTitleUrlPairs; $rssUrl) {
    !speechCancel.
    play: ~internetAccessSoundRef.
    !loadGlobalAsync rssUrl -> $xmlString fun {
        pause: ~internetAccessSoundRef.
        ($setTime propOf ~internetAccessSoundRef): 0.
        
        $domObject = domParse: xmlString.
        $items = "item" domTags domObject.
        
        # Do something with all the items
        withTitleUrlPairs: {2 eq length: ;/ x} filter !each items -> $item fun {
            $title = domInnerText: first: "title" domTags item.
            $link = domInnerText: first: "link" domTags item.
            $description = domInnerText: first: "description" domTags item.
            
            [title];[link].
        }.
    }.
}.
$titledAudioUrlsFromRssUrlAsync = !fun ($withTitleUrlPairs; $rssUrl) {
    !speechCancel.
    play: ~internetAccessSoundRef.
    !loadGlobalAsync rssUrl -> $xmlString fun {
        pause: ~internetAccessSoundRef.
        ($setTime propOf ~internetAccessSoundRef): 0.
        
        $domObject = domParse: xmlString.
        $items = "item" domTags domObject.
        
        # Do something with all the items
        $titleUrlPairs = {2 eq length: ;/ x} filter !each items -> $item fun {
            $title = domInnerText: first: "title" domTags item.
            $enclosure = first: "enclosure" domTags item.
            $link = !if ("audio/" strStartsWith "type" domAttribute enclosure) {
                `Return` "url" domAttribute enclosure
            }.
            
            [title];[link].
        }.
        
        withTitleUrlPairs:
            [$language; [domInnerText: first: "language" domTags domObject]];
            [$titleUrlPairs; [titleUrlPairs]]
    }.
}.

$paragraphsFromUrlAsync = !fun ($withParagraphs; $url) {
    !speechCancel.
    play: ~internetAccessSoundRef.
    !loadGlobalAsync url -> $htmlContent fun {
        pause: ~internetAccessSoundRef.
        ($setTime propOf ~internetAccessSoundRef): 0.

        $articleTags = "article" domTags domParseHtml: htmlContent.
        withParagraphs: ;/ ;/ !each articleTags -> $article fun {
            ;/ ;/ {not: "" eq strTrim: x} filter !each domInner: article -> $child fun {
                !ifNot (("FOOTER" eq strToUpperCase: domTagName: child) | ("STYLE" eq strToUpperCase: domTagName: child)) {
                    # print: domTagName: child.
                    $textContent = domInnerText: child.
                    !ifElse (".paywall" strStartsWith strTrim: textContent) {"Dieser Inhalt ist im Internet nicht frei zugänglich (Paywall)"};{textContent}
                }.
            }.
        }.
    }.
}.


# Speech setup
$config = parseJson: loadLocal: "/app/blindReader/resources/config.json".
$rootHierarchy = parseJson: loadLocal: "/app/blindReader/resources/" + (default: "rootHierarchy.json"): appParameter: "root".
$voices = speechGetVoicesByLanguage: $language propOf config.
$usedVoiceRef ? Var = first: voices.

$showLeftRightButtonNavigationView = !fun () {
    # Very important for knowing the intended action
    uiShowVariable: $initialStateReached ? Var = false.
    uiShowVariable: $leftDownRef ? Var = false.
    uiShowVariable: $rightDownRef ? Var = false.
    uiShowVariable: $leftHasBeenUpRef ? Var = false.
    uiShowVariable: $rightHasBeenUpRef ? Var = false.
    
    $bothFingersDown = !fun () {
        ~rightDownRef & ~leftDownRef
    }.
    
    $doAction = !fun () {
        do: first: !switch void
            [{~leftHasBeenUpRef & ~rightHasBeenUpRef}; {
                print: "goToPreviousLayer returned " + $stat = !goToPreviousLayer.
                say: !getTextForLayerStatus stat LAYER_UP
            }];
            [{~leftHasBeenUpRef}; {
                print: "goToNextLayerItem returned " + $stat = !goToNextLayerItem.
                say: !getTextForLayerStatus stat LAYER_ITEM_DOWN
            }];
            [{~rightHasBeenUpRef}; {
                goToNextLayerAsync: $stat fun {
                    print: "goToNextLayerAsync returned " + stat.
                    say: !getTextForLayerStatus stat LAYER_DOWN
                }.
            }].

        leftHasBeenUpRef = false.
        rightHasBeenUpRef = false.
    }.
    
    !listen leftDownRef $down fun {
        !ifElse (~initialStateReached) {
            # Default behavior
            # Register if the finger has been up
            !ifNot (down) {leftHasBeenUpRef = true.}.
            # If both fingers are down, do a thing
            !if bothFingersDown doAction.
        };{
            # Check if the initial state is reached
            !ifElse bothFingersDown {
                say: $fingersOnScreen propOf config.
                initialStateReached = true.
            };{
                print: "L" + down.
                !if down {say: $left propOf config}
            }
        }
    }.

    !listen rightDownRef $down fun {
        !ifElse (~initialStateReached) {
            # Default behavior
            # Register if the finger has been up
            !ifNot (down) {rightHasBeenUpRef = true.}.
            # If both fingers are down, do a thing
            !if bothFingersDown doAction.
        };{
            # Check if the initial state is reached
            !ifElse bothFingersDown {
                say: $fingersOnScreen propOf config.
                initialStateReached = true.
            };{
                print: "R" + down.
                !if down {say: $right propOf config}
            }
        }
    }.

    # Make a view with two big "buttons" - one left, one right
    @(onPointerDown: () fun {
        @(opacity 1) leftButton.
        leftDownRef = true.
    })
    @(onPointerUp: () fun {
        @(opacity 0,5) leftButton.
        leftDownRef = false.
    })
    print: $leftButton = @(opacity 0,5) @front @windowTop @left @(backgroundColor red) @fullHeight @(percentWidth 50) uiContainer: ().

    @(onPointerDown: () fun {
        @(opacity 1) rightButton.
        rightDownRef = true.
    })
    @(onPointerUp: () fun {
        @(opacity 0,5) rightButton.
        rightDownRef = false.
    })
    print: $rightButton = @(opacity 0,5) @front @windowTop @right @(backgroundColor 0;200;0) @fullHeight @(percentWidth 50) uiContainer: ().
}.

$showSwipeAndTapNavigationView = !fun () {
    @(fmOnShortPress: {
        print: "goToNextLayerItem returned " + $stat = !goToNextLayerItem.
        say: !getTextForLayerStatus stat LAYER_ITEM_DOWN
    })
    @(fmOnLongPress: {
        print: "goToPreviousLayerItem returned " + $stat = !goToPreviousLayerItem.
        say: !getTextForLayerStatus stat LAYER_ITEM_UP
    })
    @(fmOnSwipe: ($x;$y) fun {
        !ifElse (x > 0) {
            # Left - go up
            print: "goToPreviousLayer returned " + $stat = !goToPreviousLayer.
            say: !getTextForLayerStatus stat LAYER_UP
        };{
            # Right - go a level deeper
            goToNextLayerAsync: $stat fun {
                print: "goToNextLayerAsync returned " + stat.
                say: !getTextForLayerStatus stat LAYER_DOWN
            }.
        }.
    })
    @(onSecondaryTap: () fun {
        say: !getTextForLocationInHierarchy.
        print: "Secondary tap".
    })
    print: @(cssClass: "k-no_highlight") @front @windowTop @left @fullHeight @fullWidth @(backgroundColor black;122) uiContainer: ().
}.

print: !uiActionPicker voices -> {
    usedVoiceRef = (Int: x) at voices.
    say: $voiceDemo propOf config.
}.
print: !uiButton $listenToVoice propOf config -> {
    say: $voiceDemo propOf config.
}.

$navigationViewFactoryIndexRef ? Var = 0.
$navigationViewFactoryOptions =
    showLeftRightButtonNavigationView; showSwipeAndTapNavigationView.

print: !uiPicker navigationViewFactoryIndexRef
    [("leftRightButtonNavigationView" propOf config); 0];
    [("swipeAndTapNavigationView" propOf config); 1].

print: !uiButton $selectVoice propOf config -> {
    do: ~navigationViewFactoryIndexRef at navigationViewFactoryOptions.
    
    play: ~internetAccessSoundRef.
    !runLater 1000 -> {
        pause: ~internetAccessSoundRef.
        ($setTime propOf ~internetAccessSoundRef): 0.
        
        say: !getTextForLocationInHierarchy.
    }.
}.

print: uiContainer: $guide propOf config.

$say = !fun ($text) {
    !speechCancel.
    text speechSay ~usedVoiceRef
}.


($push propOf indexesInHierarchyLayers): 0.


$textTreeGenerator = !fun ($text) {
    [$title; text].
}.
$rssFeedTreeGenerator = !fun ($feedUrl) {
    `Return` !fun ($withLayer) {
        # Load stuff from the internet
        !titledUrlsFromRssUrlAsync feedUrl -> $titleUrlPairs fun {
            withLayer: !each titleUrlPairs -> $pair fun {
                # Construct a tree item
                [$title; first: pair];
                [$getLayerAsync; ($withLayer) fun {
                    # Get the content of the article
                    !paragraphsFromUrlAsync second: pair -> {
                        # print: x.
                        withLayer: textTreeGenerator each x.
                    }
                }]
            }
        }.
    }
}.
$audioTreeItem = !fun ($audioUrl) {
    # Load some audio
    $playerRef ? Var = void.
    !uiAudioPlayer audioUrl {
        play: playerRef = x.
    }.
    
    # Return a tree item that customizes the default controls
    [
        ["onNextLayerItem"; {
            ($setTime propOf ~playerRef): (do: $getProgress propOf ~playerRef) + 60.
            play: ~playerRef.
        }];
        ["onPreviousLayerItem"; {
            ($setTime propOf ~playerRef): (do: $getProgress propOf ~playerRef) - 60.
            play: ~playerRef.
        }];
        ["onBeforePreviousLayer"; {
            # print: ~playerRef.
            pause: ~playerRef.
        }]
    ]
}.
$podcastFeedTreeGenerator = !fun ($feedUrl) {
    `Return` !fun ($withLayer) {
        # Load stuff from the internet
        !titledAudioUrlsFromRssUrlAsync feedUrl -> $result fun {
            $titleUrlPairs = $titleUrlPairs propOf result.
            $language = $language propOf result.
            
            withLayer: !each titleUrlPairs -> $pair fun {
                # Construct a tree item
                (!ifNot (void eq language) {["language";language]});
                [$title; first: pair];
                [$getLayerAsync; ($withLayer) fun {
                    # Play the audio
                    withLayer: audioTreeItem: second: pair
                }]
            }
        }.
    }
}.
$tvPrimetimeTreeGenerator = !fun ($feedUrl) {
    `Return` !fun ($withLayer) {
        # Load stuff from the internet
        !titledUrlsFromRssUrlAsync feedUrl -> $titleUrlPairs fun {
            withLayer: !each {"20:15" strContains first: x} filter titleUrlPairs -> $pair fun {
                # Construct a tree item
                [$title; first: pair];
                [$getLayerAsync; ($withLayer) fun {
                    # Get the content of the article
                    !paragraphsFromUrlAsync second: pair -> {
                        # print: x.
                        withLayer: textTreeGenerator each x.
                    }
                }]
            }
        }.
    }
}.

# Fill the hierarchy with some content
($push propOf hierarchyLayers): [!each $root propOf rootHierarchy -> $rootItemInfo fun {
    [$title; $title propOf rootItemInfo];
    [$getLayerAsync; $withLayer fun {
        # Which function do we use to get the tree item?
        $generatorFunction = first: ($generatorFunction propOf rootItemInfo) switchEq
            ["rssFeedTreeGenerator"; rssFeedTreeGenerator];
            ["podcastFeedTreeGenerator"; podcastFeedTreeGenerator];
            ["tvPrimetimeTreeGenerator"; tvPrimetimeTreeGenerator].
        
        (generatorFunction: $input propOf rootItemInfo): withLayer
    }]
}].

!disableScrolling.

($push propOf allowedDomains): $allowedDomains propOf rootHierarchy.
