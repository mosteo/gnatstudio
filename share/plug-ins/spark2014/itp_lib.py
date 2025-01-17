import GPS
import json
from os import path, utime
# Import graphics Gtk libraries for proof interactive elements
from gi.repository import Gtk, Gdk
from gs_utils import make_interactive
from pygps import get_widgets_by_type

debug_mode = False
# This is a file which is used as output to the stderr of gnat_server (in cases
# it fails during manual proof edition). Use "/tmp/itp_default" for example.
debug_file = ""

# True iff manual proof is active
itp_started = False

# True iff the proof tree was initially sent
is_init = False

# Gdk colors constants
GREEN = Gdk.RGBA(0, 1, 0, 0.2)
RED = Gdk.RGBA(1, 0, 0, 0.2)

# Image in the tree
RED_CROSS = "\u274c"
HEAVY_CHECK_MARK = "\u2714"

# By default the root node of the proof tree is 0. It does not correspond to
# a visible node: it is used when no node can be found.
ROOT_NODE = 0

# Notification and requests corresponding constants. Basically any json
# strings have the same name in upper case letters. Exception made for strings
# that have to be disambigued like "Message" and "message" which are translated
# to UMESSAGE and LMESSAGE (U for uppercase and L for lowercase letter).
DEAD = "Dead"
DETACHED = "detached"
DOC = "doc"
DONE = "Done"
EXIT = "Exit_req"
LERROR = "error"
UERROR = "Error"
FAILING_ARG = "failing_arg"
FILE_CONTENTS = "File_contents"
FILE_SAVED = "File_Saved"
FULL_CONTEXT = "full_context"
HELP = "Help"
HIGHFAILURE = "HighFailure"
LINFORMATION = "information"
UINFORMATION = "Information"
INITIALIZATION_MESSAGE = "Session initialized successfully"
INITIALIZED = "Initialized"
INVALID = "Invalid"

UMESSAGE = "Message"
LMESSAGE = "message"
MESS_NOTIF = "mess_notif"
NAME = "name"
NAME_NC = "name"
NAME_CHANGE = "Name_change"
NEW_NODE = "New_node"
NEXT_UNPROVEN = "Next_Unproven_Node_Id"
NODE_CHANGE = "Node_change"
NODE_ID = "node_ID"
NODE_ID1 = "node_ID1"
NODE_ID2 = "node_ID2"
NODE_TYPE = "node_type"
NOTIFICATION = "notification"
NOTINSTALLED = "Not Installed"
NOTPROVED = "Not Proved"
NOTVALID = "Not Valid"
LOBSOLETE = "obsolete"
UOBSOLETE = "Obsolete"
OPEN_FILE_ERROR = "Open_File_Error"
OPEN_ERROR = "open_error"
PARENT_ID = "parent_ID"
PARSE_OR_TYPE_ERROR = "Parse_Or_Type_Error"
PR_ANSWER = "pr_answer"

PROOF_ATTEMPT = "proof_attempt"
PROOF_ERROR = "Proof_error"
PROOF_STATUS_CHANGE = "Proof_status_change"
PROVER_RESULT = "prover_result"
LPROVED = "proved"
UPROVED_JSON = "Proved"
UPROVED_DIS = "Proved"
QERROR = "qerror"
QHELP = "qhelp"
QINFO = "qinfo"
QUERY_INFO = "Query_Info"
QUERY_ERROR = "Query_Error"
REMOVE = "Remove"
RESET_WHOLE_TREE = "Reset_whole_tree"
LREPLAY_INFO = "replay_info"
UREPLAY_INFO = "Replay_Info"
RUNNING = "Running"
SAVE = "Save"
SAVED = "Saved"
STRAT_ERROR = "Strat_error"
LTASK = "task"
UTASK = "Task"
TASK_MONITOR = "Task_Monitor"
TIMEOUT = "Timeout"
TR_NAME = "tr_name"
TRANSF_ERROR = "Transf_error"
TR_TYPE = "NTransformation"
UNKNOWN = "Unknown"
UNINSTALLED = "Uninstalled"
UPDATE = "update"
UPDATE_INFO = "update_info"
VALID = "Valid"
WELCOME = """Welcome to Manual Proof:
type help for help
click the tree to change goal
type spark_simpl to make the goal more readable\n"""

# Constants related to the interface: name of console, prooftree etc
DEBUG_CONSOLE = "Debug Manual Proof"
ITP_CONSOLE = "Manual Proof"
PROOF_TASK = "Verification Condition.why"
PROOF_TREE_TITLE = "Proof Tree"
PROOF_TREE_SHORT = "Proof Tree"

# Column of the proof tree
COLUMN_NAME = "Name"
COLUMN_ID = "ID"
COLUMN_PARENT = "parent"
COLUMN_STATUS = "Status"

# Menu for the Manual proof
MENU_NAME = "Manual Proof Commands"


def print_debug(s):
    """print debugging information when debug_mode is set"""
    if debug_mode:
        console = GPS.Console(DEBUG_CONSOLE)
        console.write(s)


def print_error(message, prompt=True):
    """print an itp error message on the itp console"""
    console = GPS.Console(ITP_CONSOLE)
    console.write(message, mode="error")
    if prompt:
        console.write("\n> ")
    else:
        console.write("\n")


def print_message(message, prompt=True):
    """print an itp info message on the itp console"""
    console = GPS.Console(ITP_CONSOLE)
    console.write(message, mode="text")
    if prompt:
        console.write("\n> ")
    else:
        console.write("\n")


def create_color(s):
    """ converts a string "Not proved" etc into a color for the
        background color of this node on the goal tree
    """
    if s == UPROVED_DIS:
        return GREEN
    # ??? Future improvements should incorporate more colors
    elif s == INVALID:
        return RED
    elif s == NOTPROVED:
        return RED
    elif s == UOBSOLETE:
        return RED
    elif s == VALID:
        return GREEN
    elif s == NOTVALID:
        return RED
    elif s == NOTINSTALLED:
        return RED
    else:
        return RED


def create_check(s):
    """ converts a string "Not proved" etc into a check for the
        first column node on the goal tree
    """
    if s == UPROVED_DIS:
        return HEAVY_CHECK_MARK
    # ??? Future improvements should incorporate more colors
    elif s == INVALID:
        return RED_CROSS
    elif s == NOTPROVED:
        return RED_CROSS
    elif s == UOBSOLETE:
        return RED_CROSS
    elif s == VALID:
        return HEAVY_CHECK_MARK
    elif s == NOTVALID:
        return RED_CROSS
    elif s == NOTINSTALLED:
        return RED_CROSS
    else:
        return RED_CROSS


def parse_notif(j, abs_tree, proof_task):
    """ takes a Json object and a proof tree and treats the json object as a
        notification on the proof tree. It makes the appropriate updates to the
        tree model.
    """

    global is_init
    global itp_started

    if not itp_started:
        return
    print_debug(str(j))
    # Most of the changes concern only the tree part.
    tree = abs_tree.tree
    if NOTIFICATION in j:
        notif_type = j[NOTIFICATION]
    else:
        print_debug("This is a valid json string but an invalid notification")
    if notif_type == NEW_NODE:
        node_id = j[NODE_ID]
        parent_id = j[PARENT_ID]
        node_type = j[NODE_TYPE]
        name = j[NAME]
        is_detached = j[DETACHED]
        if is_detached:
            name = "(detached) " + name
            tree.add_iter(node_id, parent_id, name, node_type, INVALID)
        else:
            tree.add_iter(node_id, parent_id, name, node_type, INVALID)
            if parent_id not in tree.node_id_to_row_ref:
                # If the parent cannot be found then it is a root.
                tree.roots.append(node_id)
            if node_type == TR_TYPE:
                tree.node_jump_select(parent_id, node_id)
        print_debug(NEW_NODE)
    elif notif_type == RESET_WHOLE_TREE:
        # Initializes the tree again
        is_init = False
        tree.clear()
    elif notif_type == NODE_CHANGE:
        node_id = j[NODE_ID]
        update = j[UPDATE]
        if update[UPDATE_INFO] == UPROVED_JSON:
            if update[LPROVED]:
                tree.update_iter(node_id, 4, UPROVED_DIS)
                abs_tree.get_next_id_safe(node_id)
                if node_id in tree.roots and tree.roots_is_ok():
                    yes_no_text = "All proved. Do you want to exit ?"
                    if GPS.MDI.yes_no_dialog(yes_no_text):
                        abs_tree.exit()
            else:
                tree.update_iter(node_id, 4, NOTPROVED)
        elif update[UPDATE_INFO] == PROOF_STATUS_CHANGE:
            proof_attempt = update[PROOF_ATTEMPT]
            obsolete = update[LOBSOLETE]
            # TODO use limit  limit = update["limit"]
            if obsolete:
                tree.update_iter(node_id, 4, UOBSOLETE)
            else:
                proof_attempt_result = proof_attempt[PROOF_ATTEMPT]
                if proof_attempt_result == DONE:
                    prover_result = proof_attempt[PROVER_RESULT]
                    pr_answer = prover_result[PR_ANSWER]
                    if pr_answer == VALID:
                        tree.update_iter(node_id, 4, VALID)
                    elif pr_answer == TIMEOUT:
                        tree.update_iter(node_id, 4, TIMEOUT)
                    elif pr_answer == UNKNOWN:
                        tree.update_iter(node_id, 4, UNKNOWN)
                    elif pr_answer == HIGHFAILURE:
                        tree.update_iter(node_id, 4, HIGHFAILURE)
                    else:
                        tree.update_iter(node_id, 4, UNKNOWN)
                elif proof_attempt_result == UNINSTALLED:
                    tree.update_iter(node_id, 4, NOTINSTALLED)
                else:  # In this case it is necessary just a string
                    tree.update_iter(node_id, 4, RUNNING)
        elif update[UPDATE_INFO] == NAME_CHANGE:
            new_prover_name = update[NAME_NC]
            tree.update_iter(node_id, 2, new_prover_name)
        else:
            print_debug("TODO")
        print_debug(NODE_CHANGE)
    elif notif_type == REMOVE:
        node_id = j[NODE_ID]
        tree.remove_iter(node_id)
        print_debug(REMOVE)
    elif notif_type == NEXT_UNPROVEN:
        from_node = j[NODE_ID1]
        to_node = j[NODE_ID2]
        tree.node_jump_select(from_node, to_node)
    elif notif_type == INITIALIZED:
        print_message("Initialization done")
    elif notif_type == SAVED:
        print_message("Session saved")
        if abs_tree.save_and_exit:
            abs_tree.exit_sent = True
            abs_tree.send_request(0, EXIT)
    elif notif_type == UMESSAGE:
        parse_message(j, abs_tree)
    elif notif_type == DEAD:
        if abs_tree.exit_sent:
            abs_tree.kill()
        else:
            print_message("Fatal error in ITP server, please report !")
    elif notif_type == UTASK:
        proof_task.set_read_only(read_only=False)
        proof_task.delete()
        proof_task.insert(j[LTASK])
        proof_task.save(interactive=False)
        proof_task.set_read_only(read_only=True)
        proof_task.current_view().goto(proof_task.end_of_buffer())
        GPS.Console()
        print_debug(notif_type)
    elif notif_type == FILE_CONTENTS:
        print_debug(notif_type)
    else:
        print_debug("TODO Else")


def parse_message(j, abs_tree):
    """ Parses a message (json object) sent by the itp server. It analyses and
        print the message on the itp console.
    """
    global is_init

    notif_type = j[NOTIFICATION]
    message = j[LMESSAGE]
    message_type = message[MESS_NOTIF]
    if message_type == PROOF_ERROR:
        print_error(message[LERROR])
    elif message_type == TRANSF_ERROR:
        tr_name = message[TR_NAME]
        arg = message[FAILING_ARG]
        # TODO use loc: loc = message["loc"]
        msg = message[LERROR]
        doc = message[DOC]
        if arg == "":
            err_message = msg + "\nTranformation failed: \n" + tr_name + "\n\n"
            print_error(err_message, prompt=False)
            print_message(doc)
        else:
            err_mes = "\nTransformation failed. \nOn argument: \n" + arg
            print_error(tr_name + err_mes + " \n" + msg + "\n\n", prompt=False)
            print_message(doc)
    elif message_type == STRAT_ERROR:
        print_error(message[LERROR])
    elif message_type == UREPLAY_INFO:
        print_message(message[LREPLAY_INFO])
    elif message_type == QUERY_INFO:
        print_message(message[QINFO])
    elif message_type == QUERY_ERROR:
        print_error(message[QERROR])
    elif message_type == HELP:
        print_message(message[QHELP])
    elif message_type == UINFORMATION:
        if message[LINFORMATION] == INITIALIZATION_MESSAGE:
            is_init = True
            abs_tree.select_first_root()
            print_message(WELCOME)
        print_message(message[LINFORMATION])
    elif message_type == TASK_MONITOR:
        print_debug(notif_type)
    elif message_type == PARSE_OR_TYPE_ERROR:
        print_error(message[LERROR])
    elif message_type == UERROR:
        print_error(message[LERROR])
    elif message_type == OPEN_FILE_ERROR:
        print_error(message[OPEN_ERROR])
    elif message_type == FILE_SAVED:
        print_message(message[LINFORMATION])
    else:
        print_debug("TODO")


def find_last(s, sep, first, last):
    """ Returns the biggest int res such that res < last and s[first:res]
        finish with sep.
    """

    res = s.find(sep, first, last)
    if res == -1 or res == first:
        return(first)
    else:
        return (find_last(s, sep, (res + len(sep)), last))


class Tree:
    """ This class is used for handling of the proof tree"""

    def __init__(self):
        """ Initializes the tree """
        global is_init

        # Create a tree that can be appended anywhere
        self.box = Gtk.VBox()
        scroll = Gtk.ScrolledWindow()
        # This tree contains too much information including debug information.
        # A node is (node_ID, parent_ID, name, node_type, color, check,
        # ellipsize-mode, Ellipsize_End).
        # ??? TODO find a way to remove ellipsize modes from here.
        self.model = Gtk.TreeStore(str, str, str, str, str,
                                   Gdk.RGBA, str, bool, int)
        # Create the view as a function of the model
        self.view = Gtk.TreeView(self.model)
        self.view.set_headers_visible(True)

        # Adding the tree to the scrollbar
        scroll.add(self.view)
        self.box.pack_start(scroll, True, True, 0)

        # TODO to be found: correct groups ???
        GPS.MDI.add(self.box,
                    PROOF_TREE_TITLE,
                    PROOF_TREE_SHORT,
                    group=101,
                    position=4)

        # roots is a list of nodes that does not have parents. When they are
        # all proved, we know the check is proved.
        self.roots = []
        is_init = False

        cell = Gtk.CellRendererText()
        col2 = Gtk.TreeViewColumn(COLUMN_NAME)
        col2.pack_start(cell, True)
        col2.add_attribute(cell, "text", 2)
        col2.add_attribute(cell, "background_rgba", 5)
        # ??? Remove this ellipsize stuff from the model tree
        col2.add_attribute(cell, "ellipsize_set", 7)
        col2.add_attribute(cell, "ellipsize", 8)
        col2.set_expand(True)
        self.view.append_column(col2)

        # Node color (proved or not ?)
        cell = Gtk.CellRendererText(xalign=0)
        col = Gtk.TreeViewColumn(COLUMN_STATUS)
        col.pack_start(cell, True)
        col.add_attribute(cell, "text", 4)
        col.add_attribute(cell, "background_rgba", 5)
        col.set_expand(False)
        self.view.append_column(col)

        # TODO improve this....
        cell = Gtk.CellRendererText(xalign=0)
        col = Gtk.TreeViewColumn(" ")
        col.pack_start(cell, True)
        col.add_attribute(cell, "text", 6)
        col.add_attribute(cell, "background_rgba", 5)
        col.set_expand(False)
        self.view.append_column(col)

        # Populate with columns we want
        if debug_mode:
            # Node_ID
            cell = Gtk.CellRendererText(xalign=0)
            self.close_col = Gtk.TreeViewColumn(COLUMN_ID)
            self.close_col.pack_start(cell, True)
            self.close_col.add_attribute(cell, "text", 0)
            self.close_col.add_attribute(cell, "background_rgba", 5)
            self.view.append_column(self.close_col)

        if debug_mode:
            # Node parent
            cell = Gtk.CellRendererText(xalign=0)
            col = Gtk.TreeViewColumn(COLUMN_PARENT)
            col.pack_start(cell, True)
            col.add_attribute(cell, "text", 1)
            col.set_expand(True)
            col.add_attribute(cell, "background_rgba", 5)
            self.view.append_column(col)

        # We have a dictionnary from node_id to row_references because we want
        # an "efficient" way to get/remove/etc a particular row and we are not
        # going to go through the whole tree each time: O(n) vs O (ln n)
        # find something that do exactly this in Gtk ??? (does not exist ?)
        self.node_id_to_row_ref = {}

    def clear(self):
        """ clear the content of the tree """
        self.node_id_to_row_ref = {}
        self.roots = []
        self.model.clear()

    def get_iter(self, node):
        """ get the iter node corresponding to the server node  """
        try:
            row = self.node_id_to_row_ref[node]
            path = row.get_path()
            return (self.model.get_iter(path))
        except Exception:
            if debug_mode:
                print(("get_iter error: node does not exists %d", node))
            return None

    def set_iter(self, new_iter, node):
        """ Associate the corresponding row of an iter to its node in
            node_id_to_row_ref.
        """

        path = self.model.get_path(new_iter)
        row = Gtk.TreeRowReference.new(self.model, path)
        self.node_id_to_row_ref[node] = row

    def add_iter(self, node, parent, name, node_type, proved):
        """ creates a new node in the tree """

        parent_iter = self.get_iter(parent)
        if parent_iter is None:
            if debug_mode:
                print(("add_iter error: parent of %d does not exists: %d",
                       node, parent))

        # Append as a child of parent_iter. parent_iter can be None
        # (toplevel iter).
        new_iter = self.model.append(parent_iter)
        color = create_color(proved)
        check = create_check(proved)
        self.model[new_iter] = [str(node),
                                str(parent),
                                name,
                                node_type,
                                proved,
                                color,
                                check,
                                True,
                                3]
        self.set_iter(new_iter, node)
        # ??? We currently always expand the tree. We may not want to do that
        # in the future.
        self.view.expand_all()

    def get_parent_node(self, node):
        """ Returns the parent id of the node or 0 if the parent is
            not visible """
        try:
            node_row = self.node_id_to_row_ref[node]
            node_path = node_row.get_path()
            node_iter = self.model.get_iter(node_path)
            # ??? ad hoc way to get the parent node. This should be changed
            return(int(self.model[node_iter][1]))
        except Exception:
            return(0)

    def update_iter(self, node_id, field, value):
        """ update a node of the tree"""

        row = self.node_id_to_row_ref[node_id]
        path = row.get_path()
        iter = self.model.get_iter(path)
        if field == 4:
            color = create_color(value)
            check = create_check(value)
            self.model[iter][5] = color
            self.model[iter][6] = check
        self.model[iter][field] = value

    def remove_iter(self, node_id):
        """ remove a node from the tree """

        row = self.node_id_to_row_ref[node_id]
        path = row.get_path()
        iter = self.model.get_iter(path)
        self.model.remove(iter)
        del self.node_id_to_row_ref[node_id]

    def node_jump_select(self, from_node, to_node):
        """  Automatically jumps from from_node to to_node if from_node is
             selected """

        tree_selection = self.view.get_selection()
        try:
            if not tree_selection.count_selected_rows() == 0 and \
               from_node is not None:
                from_node_row = self.node_id_to_row_ref[from_node]
                from_node_path = from_node_row.get_path()
                parent = self.get_parent_node(from_node)
                # The root node is never printed in the tree
                if parent == 0:
                    parent = from_node
                try:
                    parent_row = self.node_id_to_row_ref[parent]
                    parent_path = parent_row.get_path()
                except Exception:
                    #  The parent is not in the partial visible tree
                    #  because of focusing. Use a default.
                    parent_path = from_node_path
                if tree_selection.path_is_selected(from_node_path) or \
                   tree_selection.path_is_selected(parent_path):
                    tree_selection.unselect_all()
                    to_node_row = self.node_id_to_row_ref[to_node]
                    to_node_path = to_node_row.get_path()
                    tree_selection.select_path(to_node_path)
            else:
                to_node_row = self.node_id_to_row_ref[to_node]
                to_node_path = to_node_row.get_path()
                tree_selection.select_path(to_node_path)
        except Exception:
            # The node we are jumping to does not exists
            err_message = "Error in jumping: the node : " + str(to_node)
            print_debug(err_message + " probably does not exists")

    def roots_is_ok(self):
        """ Check if all the roots are proved. If so, the check is proved and
            we can exit.
        """
        b = is_init
        for node_id in self.roots:
            row = self.node_id_to_row_ref[node_id]
            path = row.get_path()
            iter = self.model.get_iter(path)
            b = b and self.model[iter][4] == UPROVED_DIS
        return(b)


class MenuITP:
    """ This should create a Menu which contains all the possible
        transformations that can be launched in manual proof"""

    def start_menu(self, gnat_server, generation):
        """ This function creates the transformation menu and populates it with
            the transformations. """
        try:
            # First import generated_menus.json which contains the SPARK
            # generated menus. The file is at share/config/generated_menus.json
            install_dir = path.join(path.dirname(gnat_server),
                                    "..", "..", "..")
            generated_menus_dir = path.abspath(
                path.join(install_dir, "share", "spark",
                          "config"))
            json_gen_menu = path.join(generated_menus_dir,
                                      "generated_menus.json")
            with open(json_gen_menu, 'r') as f:
                self.generated_menus = json.load(f)

                # Use the module list to generate menus
                for sub_l in self.generated_menus:
                    if len(sub_l) == 1:
                        for n in sub_l:
                            name = "spark__itp__" + n
                            path2 = "/" + MENU_NAME + "/" + n
                            menu, b = make_interactive(name=name, menu=name,
                                                       callback=generation(n))
                            menu.menu(path=path2,
                                      ref="spark__itp__" + n,
                                      add_before=True)
                    else:
                        name_sub = sub_l[0]
                        for n in sub_l[1:]:
                            name = "spark__itp__" + name_sub + n
                            path2 = "/" + MENU_NAME + "/" + name_sub + "/" + n
                            menu, b = make_interactive(name=name, menu=name,
                                                       callback=generation(n))
                            menu.menu(path=path2,
                                      ref="spark__itp__" + n, add_before=True)
        except Exception as e:
            print(e)
            print_error("Cannot load menus: update GPS or/and SPARK")

    def kill_menu(self):
        """ Kills all transformations menu. destroy is not recursive so we need
            to remove every elements"""
        for sub_l in self.generated_menus:
            if len(sub_l) == 1:
                for n in sub_l:
                    path = "/" + MENU_NAME + "/" + n
                    # When creating, use "__"; when getting "_"
                    path = path.replace("__", "_", 42)
                    menu = GPS.Menu.get(path)
                    action = menu.action
                    action.disable(True)
                    action.destroy_ui()
                    menu.destroy()
            else:
                name_sub = sub_l[0]
                for n in sub_l[1:]:
                    path = "/" + MENU_NAME + "/" + name_sub + "/" + n
                    # When creating, use "__"; when getting "_"
                    path = path.replace("__", "_", 42)
                    menu = GPS.Menu.get(path)
                    action = menu.action
                    action.disable(True)
                    action.destroy_ui()
                    menu.destroy()


class Tree_with_process(MenuITP):
    """ This class is used for handling of interactions between the subprocess
        itp server and the whole graphical interface (especially the proof
        tree).
    """

    def __init__(self):
        # init local variables
        self.save_and_exit = False
        self.exit_sent = False
        # send_queue and size_queue are used for request sent by the IDE to ITP
        # server.
        self.send_queue = ""
        self.size_queue = 0
        self.checking_notification = False
        print_debug("ITP launched")

    def generation(self, x):
        """ generating function that is standard in python for callback of menu
            elements. If you doubt why it is useful you should probably try to
            evaluate the following:
            a = [0, 0, 0, 0, 0, 0]
            for i in range(0,5):
                a[i] = lambda : i
            # a[1]() = 4
            # a[3]() = 4
        """
        cmd = x.replace("__", "_", 42)
        return (lambda: [print_message(cmd),
                         self.interactive_console_input(ITP_CONSOLE, cmd)])

    def _on_view_button_press(self, _, event):
        """React to a button_press on the view."""

        if event.button == 3:
            gtkmenu = get_widgets_by_type(Gtk.MenuItem, None)
            item = None
            for entry in gtkmenu:
                if entry.get_label() == MENU_NAME:  # ??? good way to find this
                    item = entry
            t = item.get_submenu()
            # On this button, raise the contextual menu
            t.popup(None, None, None, None, 3, 0)
            return False
        return False

    def start(self, command, source_file_path, dir_gnat_server, artifact_dir,
              gs_loc):
        """ start interactive theorem proving """

        global itp_started

        itp_started = True
        self.file_name = source_file_path
        # init local variables
        self.save_and_exit = False
        self.exit_sent = False

        # init the tree
        self.tree = Tree()
        self.process = GPS.Process(command,
                                   regexp=">>>>",
                                   on_match=self.check_notifications,
                                   directory=dir_gnat_server,
                                   on_exit=self.exit_by_gnat_server)
        self.console = GPS.Console(ITP_CONSOLE,
                                   on_input=self.interactive_console_input)
        self.console.write("> ")
        # Back to the Messages console
        GPS.Console()

        self.start_menu(gs_loc, self.generation)
        self.tree.view.connect("button_press_event",
                               self._on_view_button_press)

        # Query task each time something is clicked
        tree_selection = self.tree.view.get_selection()
        tree_selection.set_select_function(self.select_function)

        # Create a file for the vc location at the same place as the mlw_file
        location_vc = artifact_dir
        VC_file = path.join(location_vc, PROOF_TASK)
        # Define the proof task
        proof_task_file = GPS.File(VC_file, local=True)
        self.proof_task = GPS.EditorBuffer.get(proof_task_file,
                                               force=True,
                                               open=True)
        self.proof_task.set_read_only()
        # ??? should prefer using group and position. Currently, this works.
        GPS.execute_action(action="Split horizontally")

        # Initialize the Timeout for sending requests to ITP server. 300
        # milliseconds is arbitrary. It looks like it works and it should be ok
        # for interactivity.
        self.timeout = GPS.Timeout(300, self.actual_send)

    def kill(self):
        """ Kill everything created during interactive theorem proving """

        global itp_started
        itp_started = False

        a = GPS.Console(ITP_CONSOLE)
        # Any closing destroying can fail so try are needed to avoid killing
        # nothing when the first exiting function fail.
        try:
            a.destroy()
        except Exception:
            print("Cannot close console")
        try:
            windows = GPS.MDI.children()
            for a in windows:
                if PROOF_TASK == a.name(short=True):
                    a.close(force=True)
        except Exception:
            print("Cannot close proof_task")
        try:
            windows = GPS.MDI.children()
            for a in windows:
                if PROOF_TREE_SHORT == a.name(short=True):
                    a.close(force=True)
        except Exception:
            print("Cannot close tree")
        try:
            self.process.kill()
        except BaseException:  # This is caught somewhere else and hang
            print("Cannot kill why3_server process")
        try:
            self.timeout.remove()
        except Exception:
            print("Cannot stop timeout")
        try:
            self.kill_menu()
        except Exception:
            print("Cannot remove transformations menu")

    def exit(self):
        """ exit itp """

        global itp_started

        if itp_started:
            if self.exit_sent:
                # This is the second time the user tries to exit.
                # Kill everything.
                self.kill()
            else:
                if GPS.MDI.yes_no_dialog(
                        "Do you want to save session before exit?"):
                    self.send_request(0, SAVE)
                    self.save_and_exit = True
                else:
                    self.exit_sent = True
                    self.send_request(0, EXIT)

    def exit_by_gnat_server(self, _status, _output, _unused):
        """ When the gnat_server exits, this is used to also exits the
            plugin.
        """
        self.kill()

    def check_notifications(self, unused, delimiter, notification):
        """ function used as an on_match by the GPS.Process used to launch
            the itp server. This does the server to plugin communication.
        """
        self.checking_notification = True
        print_debug(notification)
        try:
            # Remove remaining stderr output (stderr and stdout are mixed) by
            # looking for the beginning of the notification (begins with {).
            i = notification.find("{")
            notif = notification[i:]
            if notif[:10] == "{ Failure:":
                irr_error = "Irrecoverable error of manual proof." + notif
                GPS.MDI.dialog(irr_error)
                self.kill()
                return
            p = json.loads(notification[i:])
            parse_notif(p, self, self.proof_task)
        except (ValueError):
            print("Bad Json value")
            print(notification)
        except (KeyError):
            print("Bad Json key")
            print(notification)
        except (TypeError):
            print("Bad type")
            print(notification)
        self.checking_notification = False

    def select_function(self, select, model, path, currently_selected):
        """ function used as the select function of the proof tree """

        if not currently_selected:
            tree_iter = model.get_iter(path)
            node_id = model[tree_iter][0]
            self.get_task(node_id)
            self.selected_node = int(node_id)
            return True
        else:
            return True

    def select_first_root(self):
        """ This selects the first root of the tree after initialization. """

        tree_selection = self.tree.view.get_selection()
        try:
            root = self.tree.roots[0]
            if tree_selection.count_selected_rows() == 0:
                root_row = self.tree.node_id_to_row_ref[root]
                root_path = root_row.get_path()
                tree_selection.select_path(root_path)
        except Exception:
            pass

    def interactive_console_input(self, console, command):
        """ used as the on_input function of the itp Console. It parses and
            send request from the user to the itp server.
        """
        self.called = False

        def called_on_select(tree_model, tree_path, tree_iter):
            try:
                a = tree_model[tree_iter][0]
                self.called = True
                self.send_request(a, command)
            except Exception:
                pass

        tree_selection = self.tree.view.get_selection()
        tree_selection.selected_foreach(called_on_select)
        # When nothing is selected, still send the command with ROOT_NODE
        # (case for help, list-transforms etc)
        if not self.called:
            self.send_request(ROOT_NODE, command)

    def actual_send(self, useless_timeout):
        """ This function actually send data. It is called in a timeout every x
            ms or when the function send overflows its allowed buffer for send
            request (in order to reduce the number of waiting request).
        """

        print_debug("sent")
        # ??? this should not be necessary to prevent deadlock with our own
        # code here. This looks really bad and should be investigated: if this
        # kind of checks really is necessary, it should be done in function
        # send/on_match from GPS.Process (obviously not here).
        if not self.size_queue == 0 and not self.checking_notification:
            # We send only complete request and less than 4080 char
            n = find_last(self.send_queue, "\n", 0, 4080)
            if n == -1 or n == 0 or n is None:
                self.send_queue = ""
                self.size_queue = 0
            else:
                self.process.send(self.send_queue[0:n])
                self.send_queue = self.send_queue[n:]
                self.size_queue = len(self.send_queue)

    # This is used as a wrapper (for debug) that actually create the message.
    # The function really sending this is called actual_send. 2 functions are
    # necessary because we want to send several messages at once. We also want
    # to send messages regularly: this is easier to have the simplest function
    # in a timeout.
    def send(self, s):
        """ This function is used as a wrapper (for debug) that actually create
            the message. The function really sending this is called
            actual_send. 2 functions are necessary because we want to send
            several messages at once. We also want to send messages regularly:
            and this is easier to have the simplest function in a timeout.
        """

        print_debug(s)
        self.send_queue = self.send_queue + s + "\n"
        self.size_queue = self.size_queue + len(s) + 4
        # From different documentation, it can be assumed that pipes have a
        # size of at least 4096 (on all platforms). So, our heuristic is to
        # check at 3800 if it is worth sending before the timeout
        # automatically does it.
        if self.size_queue > 3800:
            self.actual_send(0)

    def command_request(self, command, node_id):
        """ Function that allows building the json object for ad hoc requests
            like save, remove node, itp commands...
        """

        print_message("")
        if command == SAVE:
            # touch source file so that gnatprove believes that gnat2why should
            # be called again. Otherwise, we change the session and the change
            # cannot be seen in gnatprove because it does not recompile.
            if path.exists(self.file_name):
                # Set the modification time as now.
                utime(self.file_name, None)
            return '{"ide_request": "Save_req"  }'
        elif command == REMOVE:
            return ('{"ide_request": "Remove_subtree", "' + NODE_ID + '":' +
                    str(node_id) + " }")
        elif command == EXIT:
            return '{"ide_request": "Exit_req"  }'
        else:
            return ('{"ide_request": "Command_req", "' + NODE_ID + '":' +
                    str(node_id) + ', "command" : ' +
                    json.dumps(command) + " }")

    def send_request(self, node_id, command):
        """ send a request parsed with command_request """
        request = self.command_request(command, node_id)
        print_debug(request)
        self.send(request)

    def get_task(self, node_id):
        """ Specific request for a new task from the itp server """
        request = ('{"ide_request": "Get_task", "' + NODE_ID + '":' +
                   str(node_id) + ', "loc": false, ' +
                   '"full_context": false }')
        self.send(request)

    def get_next_id_safe(self, modified_id):
        parent_id = self.tree.get_parent_node(modified_id)
        if is_init:
            if modified_id == self.selected_node:
                self.get_next_id(str(modified_id))
            elif parent_id == self.selected_node:
                self.get_next_id(str(parent_id))

    def get_next_id(self, modified_id):
        """ Specific request for the next unproven node to the server """
        req = ('{"ide_request": "Get_first_unproven_node", "strat": "Clever", "' +
               NODE_ID + '":')
        self.send(req + modified_id + "}")
