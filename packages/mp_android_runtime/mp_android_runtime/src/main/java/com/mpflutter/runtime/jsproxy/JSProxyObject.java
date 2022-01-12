package com.mpflutter.runtime.jsproxy;

import com.quickjs.JSArray;
import com.quickjs.JSObject;
import com.quickjs.JSValue;

import org.json.JSONArray;
import org.json.JSONObject;

public class JSProxyObject {

    public JSONObject jsonObject;
    public JSObject qjsObject;

    public JSProxyObject(JSONObject jsonObject) {
        this.jsonObject = jsonObject;
    }

    public JSProxyObject(JSObject qjsObject) {
        this.qjsObject = qjsObject;
    }

    public String optString(String key, String fallback) {
        if (jsonObject != null) {
            if (jsonObject.isNull(key)) {
                return fallback;
            }
            return jsonObject.optString(key, fallback);
        }
        else if (qjsObject != null) {
            Object v = valueFromQjsObject(key);
            if (v instanceof String) {
                return (String) v;
            }
        }
        return fallback;
    }

    public int optInt(String key) {
        return optInt(key, 0);
    }

    public int optInt(String key, int fallback) {
        if (jsonObject != null) {
            if (jsonObject.isNull(key)) {
                return fallback;
            }
            return jsonObject.optInt(key, fallback);
        }
        else if (qjsObject != null) {
            Object v = valueFromQjsObject(key);
            if (v instanceof Number) {
                return ((Number) v).intValue();
            }
        }
        return fallback;
    }

    public double optDouble(String key) {
        return optDouble(key, 0.0);
    }

    public double optDouble(String key, double fallback) {
        if (jsonObject != null) {
            if (jsonObject.isNull(key)) {
                return fallback;
            }
            return jsonObject.optDouble(key, fallback);
        }
        else if (qjsObject != null) {
            Object v = valueFromQjsObject(key);
            if (v instanceof Number) {
                return ((Number) v).doubleValue();
            }
        }
        return fallback;
    }

    public boolean optBoolean(String key) {
        return optBoolean(key, false);
    }

    public boolean optBoolean(String key, boolean fallback) {
        if (jsonObject != null) {
            if (jsonObject.isNull(key)) {
                return fallback;
            }
            return jsonObject.optBoolean(key, fallback);
        }
        else if (qjsObject != null) {
            Object v = valueFromQjsObject(key);
            if (v instanceof Boolean) {
                return (boolean) v;
            }
        }
        return fallback;
    }

    public JSProxyObject optObject(String key) {
        if (jsonObject != null) {
            Object obj = jsonObject.opt(key);
            if (obj instanceof JSONObject) {
                return new JSProxyObject((JSONObject) obj);
            }
            else if (obj instanceof JSProxyObject) {
                return (JSProxyObject) obj;
            }
        }
        else if (qjsObject != null) {
            Object v = valueFromQjsObject(key);
            if (v instanceof JSObject) {
                return new JSProxyObject((JSObject) v);
            }
        }
        return null;
    }

    public JSProxyArray optArray(String key) {
        if (jsonObject != null) {
            Object obj = jsonObject.opt(key);
            if (obj instanceof JSONArray) {
                return new JSProxyArray((JSONArray) obj);
            }
            else if (obj instanceof JSProxyArray) {
                return (JSProxyArray) obj;
            }
        }
        else if (qjsObject != null) {
            Object v = valueFromQjsObject(key);
            if (v instanceof JSArray) {
                return new JSProxyArray((JSArray) v);
            }
        }
        return null;
    }

    Object valueFromQjsObject(String key) {
        JSObject o = qjsObject;
        if (qjsObject.contains("o") && qjsObject.getType("o") == JSValue.TYPE.JS_OBJECT) {
            o = qjsObject.getObject("o");
        }
        if (o != null && o.getType() == JSValue.TYPE.JS_OBJECT) {
            if (o.contains("b")) {
                JSObject b = o.getObject("b");
                if (b != null && b.getType() == JSValue.TYPE.JS_OBJECT) {
                    JSObject obj = b.getObject(key);
                    if (obj != null && obj.getType() == JSValue.TYPE.JS_OBJECT) {
                        return obj.get("b");
                    }
                }
            }
            else if (o.contains("c")) {
                JSObject c = o.getObject("c");
                if (c != null && c.getType() == JSValue.TYPE.JS_OBJECT) {
                    JSObject obj = c.getObject(key);
                    if (obj != null && obj.getType() == JSValue.TYPE.JS_OBJECT) {
                        return obj.get("b");
                    }
                }
            }
            else if (o.contains("_nums")) {
                JSObject _nums = o.getObject("_nums");
                if (_nums != null && _nums.getType() == JSValue.TYPE.JS_OBJECT) {
                    JSObject obj = _nums.getObject(key);
                    if (obj != null && obj.getType() == JSValue.TYPE.JS_OBJECT) {
                        return obj.get("hashMapCellValue");
                    }
                }
            }
            else if (o.contains("_strings")) {
                JSObject _strings = o.getObject("_strings");
                if (_strings != null && _strings.getType() == JSValue.TYPE.JS_OBJECT) {
                    JSObject obj = _strings.getObject(key);
                    if (obj != null && obj.getType() == JSValue.TYPE.JS_OBJECT) {
                        return obj.get("hashMapCellValue");
                    }
                }
            }
            else if (o.contains(key)) {
                return o.get(key);
            }
        }
        return null;
    }

    public boolean has(String key) {
        if (jsonObject != null) {
            return jsonObject.has(key) && !jsonObject.isNull(key);
        }
        else if (qjsObject != null) {
            return !isNull(key);
        }
        else {
            return false;
        }
    }

    public boolean isNull(String key) {
        if (jsonObject != null) {
            return jsonObject.isNull(key);
        }
        else if (qjsObject != null) {
            Object v = valueFromQjsObject(key);
            return v == null;
        }
        else {
            return false;
        }
    }

    public Object opt(String key) {
        Object v = null;
        if (jsonObject != null) {
            v = jsonObject.opt(key);
        }
        else if (qjsObject != null) {
            v = valueFromQjsObject(key);
        }
        if (v instanceof JSONObject) {
            return new JSProxyObject((JSONObject) v);
        }
        else if (v instanceof JSObject) {
            return new JSProxyObject((JSObject) v);
        }
        else if (v instanceof JSONArray) {
            return new JSProxyArray((JSONArray) v);
        }
        else if (v instanceof JSArray) {
            return new JSProxyArray((JSArray) v);
        }
        return v;
    }

}