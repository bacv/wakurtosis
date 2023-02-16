# System Imports
vars = import_module("github.com/logos-co/wakurtosis/src/system_variables.star")

# Module Imports
waku = import_module(vars.WAKU_MODULE)
files = import_module(vars.FILE_HELPERS_MODULE)


def prepare_nwaku_service(plan, nwakunode_names, all_services, config_files, artifact_ids):

    # TODO MAKE SURE THEY MATCH

    prepared_ports = {}
    for i in range(len(nwakunode_names)):
        prepared_ports[vars.WAKU_RPC_PORT_ID+"_"+nwakunode_names[i]] = PortSpec(number=vars.WAKU_TCP_PORT + i,
                                            transport_protocol="TCP")
        prepared_ports[vars.PROMETHEUS_PORT_ID+"_"+nwakunode_names[i]] = PortSpec(
                number=vars.PROMETHEUS_TCP_PORT + i,
                transport_protocol="TCP")
        prepared_ports[vars.WAKU_LIBP2P_PORT_ID+"_"+nwakunode_names[i]] = PortSpec(
                number=vars.WAKU_LIBP2P_PORT + i,
                transport_protocol="TCP")


    prepared_files = {}
    for i in range(len(nwakunode_names)):
        prepared_files[vars.CONTAINER_NODE_CONFIG_FILE_LOCATION+nwakunode_names[i]] = artifact_ids[i]

    prepared_cmd = ""
    for i in range(len(nwakunode_names)):
        prepared_cmd += vars.NWAKU_ENTRYPOINT + " "
        prepared_cmd += vars.NODE_CONFIGURATION_FILE_FLAG + vars.CONTAINER_NODE_CONFIG_FILE_LOCATION +\
                        nwakunode_names[i] + "/" + config_files[i] + " "
        prepared_cmd += "--ports-shift="+str(i)
        if i != len(nwakunode_names) - 1:
            prepared_cmd += " & "

    add_service_config = ServiceConfig(
        image=vars.NWAKU_IMAGE,
        ports=prepared_ports,
        files=prepared_files,
        entrypoint=["/bin/sh", "-c"],
        cmd=[prepared_cmd]
    )

    all_services["0"] = add_service_config


def prepare_gowaku_service(gowakunode_name, all_services, config_file, artifact_id):
    add_service_config = ServiceConfig(
        image=vars.GOWAKU_IMAGE,
        ports={
            vars.WAKU_RPC_PORT_ID: PortSpec(number=vars.WAKU_TCP_PORT,
                                            transport_protocol="TCP"),
            vars.PROMETHEUS_PORT_ID: PortSpec(
                number=vars.PROMETHEUS_TCP_PORT,
                transport_protocol="TCP"),
            vars.WAKU_LIBP2P_PORT_ID: PortSpec(
                number=vars.WAKU_LIBP2P_PORT,
                transport_protocol="TCP"),
        },
        files={
            vars.CONTAINER_NODE_CONFIG_FILE_LOCATION: artifact_id
        },
        entrypoint=vars.GOWAKU_ENTRYPOINT,
        cmd=[
            vars.NODE_CONFIGURATION_FILE_FLAG +
            vars.CONTAINER_NODE_CONFIG_FILE_LOCATION + config_file
        ]
    )

    all_services[gowakunode_name] = add_service_config


def prepare_nomos_service(plan, test, test2):
    plan.print("nomos")


def instantiate_services(plan, network_topology, nodes_per_container, testing):
    """
    As we will need to access for the service information later, the structure is the following:

    services = {
        "nwaku_0": {
            "hostname": service hostname
            "peer_id" : peer id of the node, as string,
            "service_info": Kurtosis service struct, that has
                "ip": ip of the service that is running the node,
                "ports": Kurtosis PortSpec, that you can access with their respective identifier
        },
        "nwaku_1": {...},
        "gowaku_": {...}

    }

    Example:

    service_peer_id = services["nwaku_0"]["peer_id"]
    service_ip = services["nwaku_0"]["service_info"].hostname
    service_ip = services["nwaku_0"]["service_info"].ip_address
    rpc_node_number = services["nwaku_0"]["service_info"].ports["your_rpc_identifier"].number
    rpc_node_protocol = services["nwaku_0"]["service_info"].ports["your_rpc_identifier"].protocol
    """

    all_services = {}

    # Get up all nodes
    services_by_image = []
    for image in vars.NODE_IMAGES_FROM_GENNET:
        services_by_image.append({k: v for (k, v) in network_topology.items() if v["image"] == image})

    # set up dicts by batch by grouped images
    for services in services_by_image:
        if len(services) == 0:
            continue

        service_names = services.keys()
        image = services[service_names[0]]["image"]
        service_builder = service_dispatcher[image]

        for i in range(0, len(service_names), nodes_per_container):
            # We have a batch of nodes
            services_in_container = service_names[i:i+nodes_per_container]

            # Get all config file names needed
            config_file_names = [services[service_config_file]["node_config"]
                           for service_config_file in services_in_container]

            config_files_artifact_ids = [files.get_toml_configuration_artifact(plan, config_file_name,
                                                                               service_name, testing)
                for config_file_name, service_name in zip(config_file_names, services_in_container)]


            # All them in ServiceConfig
            service_builder(plan, services_in_container, all_services, config_file_names,
                            config_files_artifact_ids)
            

    all_services_information = plan.add_services(
        configs = all_services
    )
    # services_information = _add_waku_service_information(plan, all_services_information)

    return {} # services_information


def _add_waku_service_information(plan, all_services_information):

    new_services_information = {}

    for service_name in all_services_information:
        node_peer_id = waku.get_wakunode_peer_id(plan, service_name, vars.WAKU_RPC_PORT_ID)

        new_services_information[service_name] = {}
        new_services_information[service_name]["peer_id"] = node_peer_id
        new_services_information[service_name]["service_info"] = all_services_information[service_name]

    return new_services_information


service_dispatcher = {
    "go-waku": prepare_gowaku_service,
    "nim-waku": prepare_nwaku_service,
    "nomos": prepare_nomos_service
}
