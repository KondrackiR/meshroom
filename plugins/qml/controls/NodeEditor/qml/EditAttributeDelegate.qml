import QtQuick 2.7
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.3
import ImageGallery 1.0
import NodeEditor 1.0

Loader {
    id: root

    property variant graph: null
    property string nodeName: ""
    property string attributeName: ""

    property variant attribute: getAttribute(graph, nodeName, attributeName)
    readonly property variant connectedAttribute: attribute && attribute.isConnected ? attribute.connections[0] : null
    active: Qt.isQtObject(attribute)

    sourceComponent: {
        if(!Qt.isQtObject(attribute))
            return emptyDelegate;
        switch(attribute.type) {
            case Attribute.UNKNOWN: return emptyDelegate
            case Attribute.TEXTFIELD: return textfieldDelegate
            case Attribute.SLIDER: return sliderDelegate
            case Attribute.COMBOBOX: return comboboxDelegate
            case Attribute.CHECKBOX: return checkboxDelegate
            case Attribute.IMAGELIST: return imageListDelegate
            case Attribute.OBJECT3D: return emptyDelegate
        }
    }

    function getNode(graph, nodeName)
    {
        return graph.nodeByName(nodeName)
    }

    function getAttribute(graph, nodeName, attName)
    {
        if(!graph)
            return null;
        var nodeIdx = graph.nodes.rowIndex(nodeName)
        if(nodeIdx == -1)
            return null;
        var inputs = getNode(graph, nodeName).inputs //graph.nodes.data(graph.nodes.index(nodeIdx, 0), NodeCollection.InputsRole)
        var attIdx = inputs.rowIndex(attName);
        return inputs.data(inputs.index(attIdx, 0), AttributeCollection.ModelDataRole);
    }

    function setAttribute(graph, nodeName, attribute, value)
    {
        var o = attribute.serializeToJSON();
        o['node'] = nodeName;
        o['value'] = value;
        graph.setAttribute(o) ;
    }

    // attribute delegates
    Component {
        id: emptyDelegate
        Label {
            text: "ERROR: no matching delegate for " + nodeName + ":" + attributeName + " (attribute : " + attribute + ")"
            color: "red"
        }
    }
    Component {
        id: imageListDelegate
        Gallery {
            model: attribute.isConnected ? connectedAttribute.value : attribute.value
            readOnly: attribute.isConnected
            gridIcon: "qrc:///images/grid.svg"
            listIcon: "qrc:///images/list.svg"
            thumbnailSize: 60

            background: Rectangle {
                color: "#5BB1F7"
                Image {
                    anchors.fill: parent
                    source: "qrc:///images/stripes.png"
                    fillMode: Image.Tile
                    opacity: 0.5
                }
            }
            onItemAdded: {
                if(attribute.isConnected)
                    return;
                var values = attribute.value ? attribute.value : []
                if(!Array.isArray(values))
                    values = [attribute.value]
                for(var i=0; i<urls.length; ++i)
                    values.push(urls[i].replace("file://", ""));

                setAttribute(graph, nodeName, attribute, values);
            }
            onItemRemoved: {
                if(attribute.isConnected)
                    return;
                var values = attribute.value ? attribute.value : []
                if(!Array.isArray(values))
                    values = [attribute.value]
                for(var i=0; i<urls.length; ++i) {
                    var index = values.indexOf(urls[i].replace("file://",""));
                    if(index < 0)
                        return;
                    values.splice(index, 1);
                }
                setAttribute(graph, nodeName, attribute, values);
            }
        }
    }
    Component {
        id: sliderDelegate
        Slider {
            id: slider
            enabled: !attribute.isConnected
            from: attribute.min
            to: attribute.max
            stepSize: attribute.step
            value: connectedAttribute ? connectedAttribute.value : attribute.value
            onPressedChanged: {
                if(pressed || value == attribute.value || attribute.isConnected)
                    return
                setAttribute(graph, nodeName, attribute, value);
            }
            ToolTip {
                parent: slider.handle
                visible: slider.pressed
                text: {
                    var value = (slider.from + (slider.to-slider.from) * slider.position);
                    return value.toFixed(2)
                }
            }
        }
    }
    Component {
        id: textfieldDelegate
        TextField {
            readOnly: attribute.isConnected
            text: {
                var v = attribute.isConnected ? connectedAttribute.value : attribute.value
                return Array.isArray(v) ? "[Array]" : v;
            }
            selectByMouse: true
            onEditingFinished: {
                focus = false
                if(attribute.isConnected || text == attribute.value)
                    return
                setAttribute(graph, nodeName, attribute, text);
            }
        }
    }
    Component {
        id: comboboxDelegate
        ComboBox {
            enabled: !attribute.isConnected
            model: attribute.options
            Component.onCompleted: {
                currentIndex = Qt.binding(function() {
                    return find(attribute.isConnected ? connectedAttribute.value : attribute.value)
                })
            }
            onActivated: {
                if(attribute.isConnected)
                    return;
                setAttribute(graph, nodeName, attribute, textAt(index));
            }
        }
    }
    Component {
        id: checkboxDelegate
        CheckBox {
            enabled: !attribute.isConnected
            Component.onCompleted: checked = attribute.isConnected ? connectedAttribute.value : attribute.value
            onClicked: {
                if(attribute.isConnected)
                    return;
                setAttribute(graph, nodeName, attribute, checked);
            }
        }
    }
}