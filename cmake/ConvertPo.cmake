string(TOUPPER ${INPUT_ENC} upperInputEnc)
string(TOLOWER ${INPUT_ENC} lowerInputEnc)
get_filename_component(inputName ${INPUT_FILE} NAME)
execute_process(
  COMMAND ${ICONV_PRG} -f ${INPUT_ENC} -t ${OUTPUT_ENC} ${INPUT_FILE}
  OUTPUT_VARIABLE trans
  ERROR_VARIABLE err
  RESULT_VARIABLE res)
if(NOT res EQUAL 0)
  message(FATAL_ERROR "iconv failed to run correctly: ${err}")
endif()

string(REPLACE "charset=${lowerInputEnc}" "charset=${OUTPUT_CHARSET}"
  trans "${trans}")
string(REPLACE "charset=${upperInputEnc}" "charset=${OUTPUT_CHARSET}"
  trans "${trans}")
string(REPLACE "# Original translations"
  "# Generated from ${inputName}, DO NOT EDIT"
  trans "${trans}")

file(WRITE ${OUTPUT_FILE} "${trans}")
