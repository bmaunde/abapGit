*&---------------------------------------------------------------------*
*&  Include           ZABAPGIT_POPUPS
*&---------------------------------------------------------------------*

"! various popups, static methods, no class/object state
CLASS lcl_popups DEFINITION.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_popup,
             url         TYPE string,
             package     TYPE devclass,
             branch_name TYPE string,
             cancel      TYPE abap_bool,
           END OF ty_popup.

    CLASS-METHODS:
      repo_package_zip
        RAISING lcx_exception,
      create_branch_popup
        EXPORTING ev_name   TYPE string
                  ev_cancel TYPE abap_bool
        RAISING   lcx_exception,
      repo_new_offline
        RETURNING VALUE(ro_repo) TYPE REF TO lcl_repo_offline
        RAISING   lcx_exception,
      switch_branch
        IMPORTING iv_key TYPE lcl_persistence_repo=>ty_repo-key
        RAISING   lcx_exception,
      delete_branch
        IMPORTING iv_key TYPE lcl_persistence_repo=>ty_repo-key
        RAISING   lcx_exception,
      branch_list_popup
        IMPORTING iv_url           TYPE string
        RETURNING VALUE(rs_branch) TYPE lcl_git_transport=>ty_branch_list
        RAISING   lcx_exception,
      repo_popup
        IMPORTING iv_url          TYPE string
                  iv_package      TYPE devclass OPTIONAL
                  iv_branch       TYPE string DEFAULT 'refs/heads/master'
        RETURNING VALUE(rs_popup) TYPE ty_popup
        RAISING   lcx_exception ##NO_TEXT,
      repo_clone
        IMPORTING iv_url         TYPE string
        RETURNING VALUE(ro_repo) TYPE REF TO lcl_repo_online
        RAISING   lcx_exception.

ENDCLASS.

CLASS lcl_popups IMPLEMENTATION.

  DEFINE _add_dialog_fld.
    APPEND INITIAL LINE TO lt_fields ASSIGNING <ls_field>.
    <ls_field>-tabname    = &1.                             "#EC NOTEXT
    <ls_field>-fieldname  = &2.                             "#EC NOTEXT
    <ls_field>-fieldtext  = &3.                             "#EC NOTEXT
    <ls_field>-value      = &4.                             "#EC NOTEXT
    <ls_field>-field_attr = &5.                             "#EC NOTEXT
  END-OF-DEFINITION.


  METHOD repo_package_zip.

    DATA: lo_repo       TYPE REF TO lcl_repo_offline,
          ls_data       TYPE lcl_persistence_repo=>ty_repo,
          lv_returncode TYPE c,
          lt_fields     TYPE TABLE OF sval.

    FIELD-SYMBOLS: <ls_field> LIKE LINE OF lt_fields.

    "               TAB           FLD       LABEL     DEF                 ATTR
    _add_dialog_fld 'TDEVC'      'DEVCLASS' 'Package' ''                  ''.

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING
        no_value_check  = abap_true
        popup_title     = 'Export'             "#EC NOTEXT
      IMPORTING
        returncode      = lv_returncode
      TABLES
        fields          = lt_fields
      EXCEPTIONS
        error_in_fields = 1
        OTHERS          = 2.
    IF sy-subrc <> 0.
      _raise 'Error from POPUP_GET_VALUES'.
    ENDIF.
    IF lv_returncode = 'A'.
      RETURN.
    ENDIF.

    READ TABLE lt_fields INDEX 1 ASSIGNING <ls_field>.
    ASSERT sy-subrc = 0.
    TRANSLATE <ls_field>-value TO UPPER CASE.

    ls_data-key             = 'DUMMY'.
    ls_data-package         = <ls_field>-value.
    ls_data-master_language = sy-langu.

    CREATE OBJECT lo_repo
      EXPORTING
        is_data = ls_data.

    lcl_zip=>export( lo_repo ).

  ENDMETHOD.                    "repo_package_zip

  METHOD create_branch_popup.

    DATA: lv_answer TYPE c LENGTH 1,
          lt_fields TYPE TABLE OF sval.

    FIELD-SYMBOLS: <ls_field> LIKE LINE OF lt_fields.


    CLEAR ev_name.
    CLEAR ev_cancel.

*                   TAB     FLD   LABEL   DEF                       ATTR
    _add_dialog_fld 'TEXTL' 'LINE' 'Name' 'refs/heads/branch_name'  ''.

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING
        popup_title     = 'Create branch'
      IMPORTING
        returncode      = lv_answer
      TABLES
        fields          = lt_fields
      EXCEPTIONS
        error_in_fields = 1
        OTHERS          = 2 ##NO_TEXT.
    IF sy-subrc <> 0.
      _raise 'error from POPUP_GET_VALUES'.
    ENDIF.

    IF lv_answer = 'A'.
      ev_cancel = abap_true.
    ELSE.
      READ TABLE lt_fields INDEX 1 ASSIGNING <ls_field>.
      ASSERT sy-subrc = 0.
      ev_name = <ls_field>-value.
    ENDIF.

  ENDMETHOD.

  METHOD repo_new_offline.

    DATA: lv_returncode TYPE c,
          lv_url        TYPE string,
          lv_package    TYPE devclass,
          lt_fields     TYPE TABLE OF sval.

    FIELD-SYMBOLS: <ls_field> LIKE LINE OF lt_fields.


    "               TAB           FLD       LABEL     DEF                 ATTR
    _add_dialog_fld 'ABAPTXT255' 'LINE'     'Name'    ''                  ''.
    _add_dialog_fld 'TDEVC'      'DEVCLASS' 'Package' ''                  ''.

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING
        no_value_check  = abap_true
        popup_title     = 'New Offline Project'             "#EC NOTEXT
      IMPORTING
        returncode      = lv_returncode
      TABLES
        fields          = lt_fields
      EXCEPTIONS
        error_in_fields = 1
        OTHERS          = 2.
    IF sy-subrc <> 0.
      _raise 'Error from POPUP_GET_VALUES'.
    ENDIF.
    IF lv_returncode = 'A'.
      RETURN.
    ENDIF.

    READ TABLE lt_fields INDEX 1 ASSIGNING <ls_field>.
    ASSERT sy-subrc = 0.
    lv_url = <ls_field>-value.

    READ TABLE lt_fields INDEX 2 ASSIGNING <ls_field>.
    ASSERT sy-subrc = 0.
    lv_package = <ls_field>-value.
    TRANSLATE lv_package TO UPPER CASE.

    ro_repo = lcl_app=>repo_srv( )->new_offline(
      iv_url     = lv_url
      iv_package = lv_package ).

    COMMIT WORK.

  ENDMETHOD.                    "repo_new_offline

  METHOD delete_branch.

    DATA: lo_repo   TYPE REF TO lcl_repo_online,
          ls_branch TYPE lcl_git_transport=>ty_branch_list.


    lo_repo ?= lcl_app=>repo_srv( )->get( iv_key ).

    ls_branch = branch_list_popup( lo_repo->get_url( ) ).
    IF ls_branch IS INITIAL.
      RETURN.
    ENDIF.

    IF ls_branch-name = 'HEAD'.
      _raise 'cannot delete HEAD'.
    ELSEIF ls_branch-name = lo_repo->get_branch_name( ).
      _raise 'switch branch before deleting current'.
    ENDIF.

    lcl_git_porcelain=>delete_branch(
      io_repo   = lo_repo
      is_branch = ls_branch ).

    MESSAGE 'Branch deleted' TYPE 'S'.

  ENDMETHOD.

  METHOD branch_list_popup.

    DATA: lt_branches  TYPE lcl_git_transport=>ty_branch_list_tt,
          lv_answer    TYPE c LENGTH 1,
          lt_selection TYPE TABLE OF spopli.

    FIELD-SYMBOLS: <ls_sel>    LIKE LINE OF lt_selection,
                   <ls_branch> LIKE LINE OF lt_branches.


    lt_branches = lcl_git_transport=>branches( iv_url ).

    LOOP AT lt_branches ASSIGNING <ls_branch>.
      APPEND INITIAL LINE TO lt_selection ASSIGNING <ls_sel>.
      <ls_sel>-varoption = <ls_branch>-name.
    ENDLOOP.

    CALL FUNCTION 'POPUP_TO_DECIDE_LIST'
      EXPORTING
        textline1          = 'Select branch'
        titel              = 'Select branch'
        start_col          = 5
        start_row          = 10
      IMPORTING
        answer             = lv_answer
      TABLES
        t_spopli           = lt_selection
      EXCEPTIONS
        not_enough_answers = 1
        too_much_answers   = 2
        too_much_marks     = 3
        OTHERS             = 4.                             "#EC NOTEXT
    IF sy-subrc <> 0.
      _raise 'Error from POPUP_TO_DECIDE_LIST'.
    ENDIF.

    IF lv_answer = 'A'. " cancel
      RETURN.
    ENDIF.

    READ TABLE lt_selection ASSIGNING <ls_sel> WITH KEY selflag = abap_true.
    ASSERT sy-subrc = 0.

    READ TABLE lt_branches INTO rs_branch WITH KEY name = <ls_sel>-varoption.
    ASSERT sy-subrc = 0.

  ENDMETHOD.

  METHOD switch_branch.

    DATA: lo_repo  TYPE REF TO lcl_repo_online,
          ls_popup TYPE ty_popup.


    lo_repo ?= lcl_app=>repo_srv( )->get( iv_key ).

    ls_popup = repo_popup(
      iv_url     = lo_repo->get_url( )
      iv_package = lo_repo->get_package( )
      iv_branch  = lo_repo->get_branch_name( ) ).
    IF ls_popup-cancel = abap_true.
      RETURN.
    ENDIF.

    lo_repo->set_url( ls_popup-url ).
    lo_repo->set_branch_name( ls_popup-branch_name ).

    COMMIT WORK.

    lo_repo->deserialize( ).

  ENDMETHOD.

  METHOD repo_popup.

    DATA: lv_returncode TYPE c,
          lv_icon_ok    TYPE icon-name,
          lv_icon_br    TYPE icon-name,
          lt_fields     TYPE TABLE OF sval,
          lv_pattr      TYPE spo_fattr,
          lv_button2    TYPE svalbutton-buttontext,
          lv_icon2      TYPE icon-name.

    FIELD-SYMBOLS: <ls_field> LIKE LINE OF lt_fields.


    IF NOT iv_package IS INITIAL.
      lv_pattr = '05'.
    ELSE.
      lv_button2 = 'Create package' ##NO_TEXT.
      lv_icon2   = icon_msg.
    ENDIF.

*                   TAB           FLD       LABEL            DEF        ATTR
    _add_dialog_fld 'ABAPTXT255' 'LINE'     'Git Clone Url'  iv_url     ''.
    _add_dialog_fld 'TDEVC'      'DEVCLASS' 'Target Package' iv_package lv_pattr.
    _add_dialog_fld 'TEXTL'      'LINE'     'Branch'         iv_branch  '05'.

    lv_icon_ok  = icon_okay.
    lv_icon_br  = icon_workflow_fork.

    CALL FUNCTION 'POPUP_GET_VALUES_USER_BUTTONS'
      EXPORTING
        popup_title       = 'Repository'
        programname       = sy-repid
        formname          = 'BRANCH_POPUP'
        ok_pushbuttontext = 'OK'
        icon_ok_push      = lv_icon_ok
        first_pushbutton  = 'Select branch'
        icon_button_1     = lv_icon_br
        second_pushbutton = lv_button2
        icon_button_2     = lv_icon2
      IMPORTING
        returncode        = lv_returncode
      TABLES
        fields            = lt_fields
      EXCEPTIONS
        error_in_fields   = 1
        OTHERS            = 2.                              "#EC NOTEXT
    IF sy-subrc <> 0.
      _raise 'Error from POPUP_GET_VALUES'.
    ENDIF.
    IF lv_returncode = 'A'.
      rs_popup-cancel = abap_true.
      RETURN.
    ENDIF.

    READ TABLE lt_fields INDEX 1 ASSIGNING <ls_field>.
    ASSERT sy-subrc = 0.
    rs_popup-url = <ls_field>-value.
    lcl_url=>name( rs_popup-url ).         " validate

    READ TABLE lt_fields INDEX 2 ASSIGNING <ls_field>.
    ASSERT sy-subrc = 0.
    rs_popup-package = <ls_field>-value.
    TRANSLATE rs_popup-package TO UPPER CASE.

    READ TABLE lt_fields INDEX 3 ASSIGNING <ls_field>.
    ASSERT sy-subrc = 0.
    rs_popup-branch_name = <ls_field>-value.

  ENDMETHOD.

  METHOD repo_clone.

    DATA: ls_popup TYPE ty_popup.


    ls_popup = repo_popup( iv_url ).
    IF ls_popup-cancel = abap_true.
      RETURN.
    ENDIF.

    ro_repo = lcl_app=>repo_srv( )->new_online(
      iv_url         = ls_popup-url
      iv_branch_name = ls_popup-branch_name
      iv_package     = ls_popup-package ).
    ro_repo->status( ). " check for errors
    ro_repo->deserialize( ).

    COMMIT WORK.

  ENDMETHOD.                    "repo_clone

ENDCLASS.