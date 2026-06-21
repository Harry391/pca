function stop_realtime_camera_service(service)
%STOP_REALTIME_CAMERA_SERVICE Signal the realtime service process to stop.

    runtime_stop_camera_stream(service);
end
