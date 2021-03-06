package com.amolg.flutterbarcodescanner;

import android.Manifest;
import android.annotation.TargetApi;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Process;
import android.util.Log;

import com.google.android.gms.common.api.CommonStatusCodes;
import com.google.android.gms.vision.barcode.Barcode;

import java.util.Map;

import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener;

/**
 * FlutterBarcodeScannerPlugin
 */
public class FlutterBarcodeScannerPlugin implements MethodCallHandler, ActivityResultListener {
    private static final String CHANNEL = "flutter_barcode_scanner";
    private static final int REQUEST_CODE_CAMERA_PERMISSION = 3777;
    private static FlutterBarcodeScannerPlugin instance;

    private FlutterActivity activity;
    private Result pendingResult;
    private Map<String, Object> arguments;
    private boolean executeAfterPermissionGranted;

    private static final String TAG = FlutterBarcodeScannerPlugin.class.getSimpleName();
    private static final int RC_BARCODE_CAPTURE = 9001;
    public static String lineColor = "";
    public static boolean isShowFlashIcon = false;

    public FlutterBarcodeScannerPlugin(FlutterActivity activity) {
        this.activity = activity;
    }

    /**
     * Plugin registration.
     */
    public static void registerWith(PluginRegistry.Registrar registrar) {
        if (instance == null) {
            final MethodChannel channel = new MethodChannel(registrar.messenger(), CHANNEL);
            instance = new FlutterBarcodeScannerPlugin((FlutterActivity) registrar.activity());
            registrar.addActivityResultListener(instance);
            channel.setMethodCallHandler(instance);
        }
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        try {
            pendingResult = result;

            if (call.method.equals("scanBarcode")) {
                if (!(call.arguments instanceof Map)) {
                    throw new IllegalArgumentException("Plugin not passing a map as parameter: " + call.arguments);
                }
                arguments = (Map<String, Object>) call.arguments;
                lineColor = (String) arguments.get("lineColor");
                isShowFlashIcon = (boolean) arguments.get("isShowFlashIcon");
                if (null == lineColor || lineColor.equalsIgnoreCase("")) {
                    lineColor = "#DC143C";
                }
                startBarcodeScannerActivityView((String) arguments.get("cancelButtonText"));
            }
        } catch (Exception e) {
            Log.e(TAG, "onMethodCall: " + e.getLocalizedMessage());
        }
    }

    private void startBarcodeScannerActivityView(String buttonText) {
        try {
            Intent intent = new Intent(activity, BarcodeCaptureActivity.class).putExtra("cancelButtonText", buttonText);
            activity.startActivityForResult(intent, RC_BARCODE_CAPTURE);
        } catch (Exception e) {
            Log.e(TAG, "startView: " + e.getLocalizedMessage());
        }
    }


    /**
     * Get the barcode scanning results in onActivityResult
     *
     * @param requestCode
     * @param resultCode
     * @param data
     * @return
     */
    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == RC_BARCODE_CAPTURE) {
            if (resultCode == CommonStatusCodes.SUCCESS) {
                if (data != null) {
                    try {
                        Barcode barcode = data.getParcelableExtra(BarcodeCaptureActivity.BarcodeObject);
                        String barcodeResult = barcode.displayValue;
                        pendingResult.success(barcodeResult);
                    } catch (Exception e) {
                        pendingResult.success("");
                    }
                } else {
                    pendingResult.success("");
                }
                pendingResult = null;
                arguments = null;
                return true;
            } else {
                pendingResult.success("");
            }
        }
        return false;
    }
}