function service = start_realtime_camera_service(rootDir)
%START_REALTIME_CAMERA_SERVICE Start the realtime camera/alignment service.

    add_runtime_services(rootDir);
    service = runtime_start_camera_stream(rootDir);
end
