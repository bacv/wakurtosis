# System Imports
system_variables = import_module("github.com/logos-co/wakurtosis/src/system_variables.star")

# Module Imports
files = import_module(system_variables.FILE_HELPERS_MODULE)


def send_req(plan, service_id, port_id, endpoint, method, body, extract={}):
    recipe = struct(
        service_id=service_id,
        port_id=port_id,
        endpoint=endpoint,
        method=method,
        content_type="application/json",
        body=body,
        extract=extract
    )

    response = plan.wait(recipe=recipe,
                    field="code",
                    assertion="==",
                    target_value=200)

    return response


def get_nomos_peer_id(plan, service_id, port_id):
    extract = {"peer_id": '.peer_id'}

    response = send_req(plan, service_id, port_id, system_variables.NOMOS_NET_INFO_URL,
                             "GET", "", extract)

    plan.assert(value=response["code"], assertion="==", target_value = 200)

    return response["extract.peer_id"]


def create_nomos_id(nomos_service_information):
    nomos_service = nomos_service_information["service_info"]

    ip = nomos_service.ip_address
    port = nomos_service.ports[system_variables.NOMOS_LIBP2P_PORT_ID].number
    nomos_node_id = nomos_service_information["peer_id"]

    return '"/ip4/' + str(ip) + '/tcp/' + str(port) + '/p2p/' + nomos_node_id + '"'


def _merge_peer_ids(peer_ids):
    return "[" + ",".join(peer_ids) + "]"


def connect_nomos_to_peers(plan, service_id, port_id, peer_ids):
    body = _merge_peer_ids(peer_ids)

    response = send_req(plan, service_id, port_id, system_variables.NOMOS_NET_CONN_URL,
                             "POST", body) 

    plan.assert(value=response["code"], assertion="==", target_value = 200)

    plan.print(response)


def make_service_wait(plan,service_id, time):
    exec_recipe = struct(
        service_id=service_id,
        command=["sleep", time]
    )
    plan.exec(exec_recipe)



def interconnect_nomos_nodes(plan, topology_information, services):
    # Interconnect them
    for nomos_service_id in services.keys():
        peers = topology_information[nomos_service_id]["static_nodes"]

        peer_ids = [create_nomos_id(services[peer]) for peer in peers]

        connect_nomos_to_peers(plan, nomos_service_id, system_variables.NOMOS_HTTP_PORT_ID, peer_ids)


