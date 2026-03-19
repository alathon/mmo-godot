#
# BSD 3-Clause License
#
# Copyright (c) 2018 - 2023, Oleg Malyavkin
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# DEBUG_TAB redefine this "  " if you need, example: const DEBUG_TAB = "\t"

const PROTO_VERSION = 3

const DEBUG_TAB : String = "  "

enum PB_ERR {
	NO_ERRORS = 0,
	VARINT_NOT_FOUND = -1,
	REPEATED_COUNT_NOT_FOUND = -2,
	REPEATED_COUNT_MISMATCH = -3,
	LENGTHDEL_SIZE_NOT_FOUND = -4,
	LENGTHDEL_SIZE_MISMATCH = -5,
	PACKAGE_SIZE_MISMATCH = -6,
	UNDEFINED_STATE = -7,
	PARSE_INCOMPLETE = -8,
	REQUIRED_FIELDS = -9
}

enum PB_DATA_TYPE {
	INT32 = 0,
	SINT32 = 1,
	UINT32 = 2,
	INT64 = 3,
	SINT64 = 4,
	UINT64 = 5,
	BOOL = 6,
	ENUM = 7,
	FIXED32 = 8,
	SFIXED32 = 9,
	FLOAT = 10,
	FIXED64 = 11,
	SFIXED64 = 12,
	DOUBLE = 13,
	STRING = 14,
	BYTES = 15,
	MESSAGE = 16,
	MAP = 17
}

const DEFAULT_VALUES_2 = {
	PB_DATA_TYPE.INT32: null,
	PB_DATA_TYPE.SINT32: null,
	PB_DATA_TYPE.UINT32: null,
	PB_DATA_TYPE.INT64: null,
	PB_DATA_TYPE.SINT64: null,
	PB_DATA_TYPE.UINT64: null,
	PB_DATA_TYPE.BOOL: null,
	PB_DATA_TYPE.ENUM: null,
	PB_DATA_TYPE.FIXED32: null,
	PB_DATA_TYPE.SFIXED32: null,
	PB_DATA_TYPE.FLOAT: null,
	PB_DATA_TYPE.FIXED64: null,
	PB_DATA_TYPE.SFIXED64: null,
	PB_DATA_TYPE.DOUBLE: null,
	PB_DATA_TYPE.STRING: null,
	PB_DATA_TYPE.BYTES: null,
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: null
}

const DEFAULT_VALUES_3 = {
	PB_DATA_TYPE.INT32: 0,
	PB_DATA_TYPE.SINT32: 0,
	PB_DATA_TYPE.UINT32: 0,
	PB_DATA_TYPE.INT64: 0,
	PB_DATA_TYPE.SINT64: 0,
	PB_DATA_TYPE.UINT64: 0,
	PB_DATA_TYPE.BOOL: false,
	PB_DATA_TYPE.ENUM: 0,
	PB_DATA_TYPE.FIXED32: 0,
	PB_DATA_TYPE.SFIXED32: 0,
	PB_DATA_TYPE.FLOAT: 0.0,
	PB_DATA_TYPE.FIXED64: 0,
	PB_DATA_TYPE.SFIXED64: 0,
	PB_DATA_TYPE.DOUBLE: 0.0,
	PB_DATA_TYPE.STRING: "",
	PB_DATA_TYPE.BYTES: [],
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: []
}

enum PB_TYPE {
	VARINT = 0,
	FIX64 = 1,
	LENGTHDEL = 2,
	STARTGROUP = 3,
	ENDGROUP = 4,
	FIX32 = 5,
	UNDEFINED = 8
}

enum PB_RULE {
	OPTIONAL = 0,
	REQUIRED = 1,
	REPEATED = 2,
	RESERVED = 3
}

enum PB_SERVICE_STATE {
	FILLED = 0,
	UNFILLED = 1
}

class PBField:
	func _init(a_name : String, a_type : int, a_rule : int, a_tag : int, packed : bool, a_value = null):
		name = a_name
		type = a_type
		rule = a_rule
		tag = a_tag
		option_packed = packed
		value = a_value
		
	var name : String
	var type : int
	var rule : int
	var tag : int
	var option_packed : bool
	var value
	var is_map_field : bool = false
	var option_default : bool = false

class PBTypeTag:
	var ok : bool = false
	var type : int
	var tag : int
	var offset : int

class PBServiceField:
	var field : PBField
	var func_ref = null
	var state : int = PB_SERVICE_STATE.UNFILLED

class PBPacker:
	static func convert_signed(n : int) -> int:
		if n < -2147483648:
			return (n << 1) ^ (n >> 63)
		else:
			return (n << 1) ^ (n >> 31)

	static func deconvert_signed(n : int) -> int:
		if n & 0x01:
			return ~(n >> 1)
		else:
			return (n >> 1)

	static func pack_varint(value) -> PackedByteArray:
		var varint : PackedByteArray = PackedByteArray()
		if typeof(value) == TYPE_BOOL:
			if value:
				value = 1
			else:
				value = 0
		for _i in range(9):
			var b = value & 0x7F
			value >>= 7
			if value:
				varint.append(b | 0x80)
			else:
				varint.append(b)
				break
		if varint.size() == 9 && (varint[8] & 0x80 != 0):
			varint.append(0x01)
		return varint

	static func pack_bytes(value, count : int, data_type : int) -> PackedByteArray:
		var bytes : PackedByteArray = PackedByteArray()
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_float(value)
			bytes = spb.get_data_array()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_double(value)
			bytes = spb.get_data_array()
		else:
			for _i in range(count):
				bytes.append(value & 0xFF)
				value >>= 8
		return bytes

	static func unpack_bytes(bytes : PackedByteArray, index : int, count : int, data_type : int):
		if data_type == PB_DATA_TYPE.FLOAT:
			return bytes.decode_float(index)
		elif data_type == PB_DATA_TYPE.DOUBLE:
			return bytes.decode_double(index)
		else:
			# Convert to big endian
			var slice: PackedByteArray = bytes.slice(index, index + count)
			slice.reverse()
			return slice

	static func unpack_varint(varint_bytes) -> int:
		var value : int = 0
		var i: int = varint_bytes.size() - 1
		while i > -1:
			value = (value << 7) | (varint_bytes[i] & 0x7F)
			i -= 1
		return value

	static func pack_type_tag(type : int, tag : int) -> PackedByteArray:
		return pack_varint((tag << 3) | type)

	static func isolate_varint(bytes : PackedByteArray, index : int) -> PackedByteArray:
		var i: int = index
		while i <= index + 10: # Protobuf varint max size is 10 bytes
			if !(bytes[i] & 0x80):
				return bytes.slice(index, i + 1)
			i += 1
		return [] # Unreachable

	static func unpack_type_tag(bytes : PackedByteArray, index : int) -> PBTypeTag:
		var varint_bytes : PackedByteArray = isolate_varint(bytes, index)
		var result : PBTypeTag = PBTypeTag.new()
		if varint_bytes.size() != 0:
			result.ok = true
			result.offset = varint_bytes.size()
			var unpacked : int = unpack_varint(varint_bytes)
			result.type = unpacked & 0x07
			result.tag = unpacked >> 3
		return result

	static func pack_length_delimeted(type : int, tag : int, bytes : PackedByteArray) -> PackedByteArray:
		var result : PackedByteArray = pack_type_tag(type, tag)
		result.append_array(pack_varint(bytes.size()))
		result.append_array(bytes)
		return result

	static func pb_type_from_data_type(data_type : int) -> int:
		if data_type == PB_DATA_TYPE.INT32 || data_type == PB_DATA_TYPE.SINT32 || data_type == PB_DATA_TYPE.UINT32 || data_type == PB_DATA_TYPE.INT64 || data_type == PB_DATA_TYPE.SINT64 || data_type == PB_DATA_TYPE.UINT64 || data_type == PB_DATA_TYPE.BOOL || data_type == PB_DATA_TYPE.ENUM:
			return PB_TYPE.VARINT
		elif data_type == PB_DATA_TYPE.FIXED32 || data_type == PB_DATA_TYPE.SFIXED32 || data_type == PB_DATA_TYPE.FLOAT:
			return PB_TYPE.FIX32
		elif data_type == PB_DATA_TYPE.FIXED64 || data_type == PB_DATA_TYPE.SFIXED64 || data_type == PB_DATA_TYPE.DOUBLE:
			return PB_TYPE.FIX64
		elif data_type == PB_DATA_TYPE.STRING || data_type == PB_DATA_TYPE.BYTES || data_type == PB_DATA_TYPE.MESSAGE || data_type == PB_DATA_TYPE.MAP:
			return PB_TYPE.LENGTHDEL
		else:
			return PB_TYPE.UNDEFINED

	static func pack_field(field : PBField) -> PackedByteArray:
		var type : int = pb_type_from_data_type(field.type)
		var type_copy : int = type
		if field.rule == PB_RULE.REPEATED && field.option_packed:
			type = PB_TYPE.LENGTHDEL
		var head : PackedByteArray = pack_type_tag(type, field.tag)
		var data : PackedByteArray = PackedByteArray()
		if type == PB_TYPE.VARINT:
			var value
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						value = convert_signed(v)
					else:
						value = v
					data.append_array(pack_varint(value))
				return data
			else:
				if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
					value = convert_signed(field.value)
				else:
					value = field.value
				data = pack_varint(value)
		elif type == PB_TYPE.FIX32:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 4, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 4, field.type))
		elif type == PB_TYPE.FIX64:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 8, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 8, field.type))
		elif type == PB_TYPE.LENGTHDEL:
			if field.rule == PB_RULE.REPEATED:
				if type_copy == PB_TYPE.VARINT:
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						var signed_value : int
						for v in field.value:
							signed_value = convert_signed(v)
							data.append_array(pack_varint(signed_value))
					else:
						for v in field.value:
							data.append_array(pack_varint(v))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX32:
					for v in field.value:
						data.append_array(pack_bytes(v, 4, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX64:
					for v in field.value:
						data.append_array(pack_bytes(v, 8, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif field.type == PB_DATA_TYPE.STRING:
					for v in field.value:
						var obj = v.to_utf8_buffer()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
				elif field.type == PB_DATA_TYPE.BYTES:
					for v in field.value:
						data.append_array(pack_length_delimeted(type, field.tag, v))
					return data
				elif typeof(field.value[0]) == TYPE_OBJECT:
					for v in field.value:
						var obj : PackedByteArray = v.to_bytes()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
			else:
				if field.type == PB_DATA_TYPE.STRING:
					var str_bytes : PackedByteArray = field.value.to_utf8_buffer()
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && str_bytes.size() > 0):
						data.append_array(str_bytes)
						return pack_length_delimeted(type, field.tag, data)
				if field.type == PB_DATA_TYPE.BYTES:
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && field.value.size() > 0):
						data.append_array(field.value)
						return pack_length_delimeted(type, field.tag, data)
				elif typeof(field.value) == TYPE_OBJECT:
					var obj : PackedByteArray = field.value.to_bytes()
					if obj.size() > 0:
						data.append_array(obj)
					return pack_length_delimeted(type, field.tag, data)
				else:
					pass
		if data.size() > 0:
			head.append_array(data)
			return head
		else:
			return data

	static func skip_unknown_field(bytes : PackedByteArray, offset : int, type : int) -> int:
		if type == PB_TYPE.VARINT:
			return offset + isolate_varint(bytes, offset).size()
		if type == PB_TYPE.FIX64:
			return offset + 8
		if type == PB_TYPE.LENGTHDEL:
			var length_bytes : PackedByteArray = isolate_varint(bytes, offset)
			var length : int = unpack_varint(length_bytes)
			return offset + length_bytes.size() + length
		if type == PB_TYPE.FIX32:
			return offset + 4
		return PB_ERR.UNDEFINED_STATE

	static func unpack_field(bytes : PackedByteArray, offset : int, field : PBField, type : int, message_func_ref) -> int:
		if field.rule == PB_RULE.REPEATED && type != PB_TYPE.LENGTHDEL && field.option_packed:
			var count = isolate_varint(bytes, offset)
			if count.size() > 0:
				offset += count.size()
				count = unpack_varint(count)
				if type == PB_TYPE.VARINT:
					var val
					var counter = offset + count
					while offset < counter:
						val = isolate_varint(bytes, offset)
						if val.size() > 0:
							offset += val.size()
							val = unpack_varint(val)
							if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
								val = deconvert_signed(val)
							elif field.type == PB_DATA_TYPE.BOOL:
								if val:
									val = true
								else:
									val = false
							field.value.append(val)
						else:
							return PB_ERR.REPEATED_COUNT_MISMATCH
					return offset
				elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
					var type_size
					if type == PB_TYPE.FIX32:
						type_size = 4
					else:
						type_size = 8
					var val
					var counter = offset + count
					while offset < counter:
						if (offset + type_size) > bytes.size():
							return PB_ERR.REPEATED_COUNT_MISMATCH
						val = unpack_bytes(bytes, offset, type_size, field.type)
						offset += type_size
						field.value.append(val)
					return offset
			else:
				return PB_ERR.REPEATED_COUNT_NOT_FOUND
		else:
			if type == PB_TYPE.VARINT:
				var val = isolate_varint(bytes, offset)
				if val.size() > 0:
					offset += val.size()
					val = unpack_varint(val)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						val = deconvert_signed(val)
					elif field.type == PB_DATA_TYPE.BOOL:
						if val:
							val = true
						else:
							val = false
					if field.rule == PB_RULE.REPEATED:
						field.value.append(val)
					else:
						field.value = val
				else:
					return PB_ERR.VARINT_NOT_FOUND
				return offset
			elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
				var type_size
				if type == PB_TYPE.FIX32:
					type_size = 4
				else:
					type_size = 8
				var val
				if (offset + type_size) > bytes.size():
					return PB_ERR.REPEATED_COUNT_MISMATCH
				val = unpack_bytes(bytes, offset, type_size, field.type)
				offset += type_size
				if field.rule == PB_RULE.REPEATED:
					field.value.append(val)
				else:
					field.value = val
				return offset
			elif type == PB_TYPE.LENGTHDEL:
				var inner_size = isolate_varint(bytes, offset)
				if inner_size.size() > 0:
					offset += inner_size.size()
					inner_size = unpack_varint(inner_size)
					if inner_size >= 0:
						if inner_size + offset > bytes.size():
							return PB_ERR.LENGTHDEL_SIZE_MISMATCH
						if message_func_ref != null:
							var message = message_func_ref.call()
							if inner_size > 0:
								var sub_offset = message.from_bytes(bytes, offset, inner_size + offset)
								if sub_offset > 0:
									if sub_offset - offset >= inner_size:
										offset = sub_offset
										return offset
									else:
										return PB_ERR.LENGTHDEL_SIZE_MISMATCH
								return sub_offset
							else:
								return offset
						elif field.type == PB_DATA_TYPE.STRING:
							var str_bytes : PackedByteArray = bytes.slice(offset, inner_size + offset)
							if field.rule == PB_RULE.REPEATED:
								field.value.append(str_bytes.get_string_from_utf8())
							else:
								field.value = str_bytes.get_string_from_utf8()
							return offset + inner_size
						elif field.type == PB_DATA_TYPE.BYTES:
							var val_bytes : PackedByteArray = bytes.slice(offset, inner_size + offset)
							if field.rule == PB_RULE.REPEATED:
								field.value.append(val_bytes)
							else:
								field.value = val_bytes
							return offset + inner_size
					else:
						return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
				else:
					return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
		return PB_ERR.UNDEFINED_STATE

	static func unpack_message(data, bytes : PackedByteArray, offset : int, limit : int) -> int:
		while true:
			var tt : PBTypeTag = unpack_type_tag(bytes, offset)
			if tt.ok:
				offset += tt.offset
				if data.has(tt.tag):
					var service : PBServiceField = data[tt.tag]
					var type : int = pb_type_from_data_type(service.field.type)
					if type == tt.type || (tt.type == PB_TYPE.LENGTHDEL && service.field.rule == PB_RULE.REPEATED && service.field.option_packed):
						var res : int = unpack_field(bytes, offset, service.field, type, service.func_ref)
						if res > 0:
							service.state = PB_SERVICE_STATE.FILLED
							offset = res
							if offset == limit:
								return offset
							elif offset > limit:
								return PB_ERR.PACKAGE_SIZE_MISMATCH
						elif res < 0:
							return res
						else:
							break
				else:
					var res : int = skip_unknown_field(bytes, offset, tt.type)
					if res > 0:
						offset = res
						if offset == limit:
							return offset
						elif offset > limit:
							return PB_ERR.PACKAGE_SIZE_MISMATCH
					elif res < 0:
						return res
					else:
						break							
			else:
				return offset
		return PB_ERR.UNDEFINED_STATE

	static func pack_message(data) -> PackedByteArray:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : PackedByteArray = PackedByteArray()
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result.append_array(pack_field(data[i].field))
			elif data[i].field.rule == PB_RULE.REQUIRED:
				print("Error: required field is not filled: Tag:", data[i].field.tag)
				return PackedByteArray()
		return result

	static func check_required(data) -> bool:
		var keys : Array = data.keys()
		for i in keys:
			if data[i].field.rule == PB_RULE.REQUIRED && data[i].state == PB_SERVICE_STATE.UNFILLED:
				return false
		return true

	static func construct_map(key_values):
		var result = {}
		for kv in key_values:
			result[kv.get_key()] = kv.get_value()
		return result
	
	static func tabulate(text : String, nesting : int) -> String:
		var tab : String = ""
		for _i in range(nesting):
			tab += DEBUG_TAB
		return tab + text
	
	static func value_to_string(value, field : PBField, nesting : int) -> String:
		var result : String = ""
		var text : String
		if field.type == PB_DATA_TYPE.MESSAGE:
			result += "{"
			nesting += 1
			text = message_to_string(value.data, nesting)
			if text != "":
				result += "\n" + text
				nesting -= 1
				result += tabulate("}", nesting)
			else:
				nesting -= 1
				result += "}"
		elif field.type == PB_DATA_TYPE.BYTES:
			result += "<"
			for i in range(value.size()):
				result += str(value[i])
				if i != (value.size() - 1):
					result += ", "
			result += ">"
		elif field.type == PB_DATA_TYPE.STRING:
			result += "\"" + value + "\""
		elif field.type == PB_DATA_TYPE.ENUM:
			result += "ENUM::" + str(value)
		else:
			result += str(value)
		return result
	
	static func field_to_string(field : PBField, nesting : int) -> String:
		var result : String = tabulate(field.name + ": ", nesting)
		if field.type == PB_DATA_TYPE.MAP:
			if field.value.size() > 0:
				result += "(\n"
				nesting += 1
				for i in range(field.value.size()):
					var local_key_value = field.value[i].data[1].field
					result += tabulate(value_to_string(local_key_value.value, local_key_value, nesting), nesting) + ": "
					local_key_value = field.value[i].data[2].field
					result += value_to_string(local_key_value.value, local_key_value, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate(")", nesting)
			else:
				result += "()"
		elif field.rule == PB_RULE.REPEATED:
			if field.value.size() > 0:
				result += "[\n"
				nesting += 1
				for i in range(field.value.size()):
					result += tabulate(str(i) + ": ", nesting)
					result += value_to_string(field.value[i], field, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate("]", nesting)
			else:
				result += "[]"
		else:
			result += value_to_string(field.value, field, nesting)
		result += ";\n"
		return result
		
	static func message_to_string(data, nesting : int = 0) -> String:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : String = ""
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result += field_to_string(data[i].field, nesting)
			elif data[i].field.rule == PB_RULE.REQUIRED:
				result += data[i].field.name + ": " + "error"
		return result



############### USER DATA BEGIN ################


enum DecayType {
	DECAY_LINEAR = 0,
	DECAY_EXPONENTIAL = 1
}

class Impulse:
	func _init():
		var service
		
		__vel_x = PBField.new("vel_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __vel_x
		data[__vel_x.tag] = service
		
		__vel_y = PBField.new("vel_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __vel_y
		data[__vel_y.tag] = service
		
		__vel_z = PBField.new("vel_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __vel_z
		data[__vel_z.tag] = service
		
		__start_tick = PBField.new("start_tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __start_tick
		data[__start_tick.tag] = service
		
		__duration_ticks = PBField.new("duration_ticks", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __duration_ticks
		data[__duration_ticks.tag] = service
		
		__decay_type = PBField.new("decay_type", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __decay_type
		data[__decay_type.tag] = service
		
	var data = {}
	
	var __vel_x: PBField
	func has_vel_x() -> bool:
		if __vel_x.value != null:
			return true
		return false
	func get_vel_x() -> float:
		return __vel_x.value
	func clear_vel_x() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__vel_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_vel_x(value : float) -> void:
		__vel_x.value = value
	
	var __vel_y: PBField
	func has_vel_y() -> bool:
		if __vel_y.value != null:
			return true
		return false
	func get_vel_y() -> float:
		return __vel_y.value
	func clear_vel_y() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__vel_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_vel_y(value : float) -> void:
		__vel_y.value = value
	
	var __vel_z: PBField
	func has_vel_z() -> bool:
		if __vel_z.value != null:
			return true
		return false
	func get_vel_z() -> float:
		return __vel_z.value
	func clear_vel_z() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__vel_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_vel_z(value : float) -> void:
		__vel_z.value = value
	
	var __start_tick: PBField
	func has_start_tick() -> bool:
		if __start_tick.value != null:
			return true
		return false
	func get_start_tick() -> int:
		return __start_tick.value
	func clear_start_tick() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__start_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_start_tick(value : int) -> void:
		__start_tick.value = value
	
	var __duration_ticks: PBField
	func has_duration_ticks() -> bool:
		if __duration_ticks.value != null:
			return true
		return false
	func get_duration_ticks() -> int:
		return __duration_ticks.value
	func clear_duration_ticks() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__duration_ticks.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_duration_ticks(value : int) -> void:
		__duration_ticks.value = value
	
	var __decay_type: PBField
	func has_decay_type() -> bool:
		if __decay_type.value != null:
			return true
		return false
	func get_decay_type():
		return __decay_type.value
	func clear_decay_type() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__decay_type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_decay_type(value) -> void:
		__decay_type.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class PlayerInput:
	func _init():
		var service
		
		__input_x = PBField.new("input_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __input_x
		data[__input_x.tag] = service
		
		__input_z = PBField.new("input_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __input_z
		data[__input_z.tag] = service
		
		__jump_pressed = PBField.new("jump_pressed", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __jump_pressed
		data[__jump_pressed.tag] = service
		
		__tick = PBField.new("tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __tick
		data[__tick.tag] = service
		
		__rot_y = PBField.new("rot_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __rot_y
		data[__rot_y.tag] = service
		
	var data = {}
	
	var __input_x: PBField
	func has_input_x() -> bool:
		if __input_x.value != null:
			return true
		return false
	func get_input_x() -> float:
		return __input_x.value
	func clear_input_x() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__input_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_input_x(value : float) -> void:
		__input_x.value = value
	
	var __input_z: PBField
	func has_input_z() -> bool:
		if __input_z.value != null:
			return true
		return false
	func get_input_z() -> float:
		return __input_z.value
	func clear_input_z() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__input_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_input_z(value : float) -> void:
		__input_z.value = value
	
	var __jump_pressed: PBField
	func has_jump_pressed() -> bool:
		if __jump_pressed.value != null:
			return true
		return false
	func get_jump_pressed() -> bool:
		return __jump_pressed.value
	func clear_jump_pressed() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__jump_pressed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_jump_pressed(value : bool) -> void:
		__jump_pressed.value = value
	
	var __tick: PBField
	func has_tick() -> bool:
		if __tick.value != null:
			return true
		return false
	func get_tick() -> int:
		return __tick.value
	func clear_tick() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_tick(value : int) -> void:
		__tick.value = value
	
	var __rot_y: PBField
	func has_rot_y() -> bool:
		if __rot_y.value != null:
			return true
		return false
	func get_rot_y() -> float:
		return __rot_y.value
	func clear_rot_y() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__rot_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_rot_y(value : float) -> void:
		__rot_y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class EntityState:
	func _init():
		var service
		
		__entity_id = PBField.new("entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __entity_id
		data[__entity_id.tag] = service
		
		__pos_x = PBField.new("pos_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __pos_x
		data[__pos_x.tag] = service
		
		__pos_y = PBField.new("pos_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __pos_y
		data[__pos_y.tag] = service
		
		__pos_z = PBField.new("pos_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __pos_z
		data[__pos_z.tag] = service
		
		__vel_x = PBField.new("vel_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __vel_x
		data[__vel_x.tag] = service
		
		__vel_y = PBField.new("vel_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __vel_y
		data[__vel_y.tag] = service
		
		__vel_z = PBField.new("vel_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __vel_z
		data[__vel_z.tag] = service
		
		__rot_y = PBField.new("rot_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __rot_y
		data[__rot_y.tag] = service
		
		__active_impulse = PBField.new("active_impulse", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __active_impulse
		service.func_ref = Callable(self, "new_active_impulse")
		data[__active_impulse.tag] = service
		
	var data = {}
	
	var __entity_id: PBField
	func has_entity_id() -> bool:
		if __entity_id.value != null:
			return true
		return false
	func get_entity_id() -> int:
		return __entity_id.value
	func clear_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_entity_id(value : int) -> void:
		__entity_id.value = value
	
	var __pos_x: PBField
	func has_pos_x() -> bool:
		if __pos_x.value != null:
			return true
		return false
	func get_pos_x() -> float:
		return __pos_x.value
	func clear_pos_x() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__pos_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_pos_x(value : float) -> void:
		__pos_x.value = value
	
	var __pos_y: PBField
	func has_pos_y() -> bool:
		if __pos_y.value != null:
			return true
		return false
	func get_pos_y() -> float:
		return __pos_y.value
	func clear_pos_y() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__pos_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_pos_y(value : float) -> void:
		__pos_y.value = value
	
	var __pos_z: PBField
	func has_pos_z() -> bool:
		if __pos_z.value != null:
			return true
		return false
	func get_pos_z() -> float:
		return __pos_z.value
	func clear_pos_z() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__pos_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_pos_z(value : float) -> void:
		__pos_z.value = value
	
	var __vel_x: PBField
	func has_vel_x() -> bool:
		if __vel_x.value != null:
			return true
		return false
	func get_vel_x() -> float:
		return __vel_x.value
	func clear_vel_x() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__vel_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_vel_x(value : float) -> void:
		__vel_x.value = value
	
	var __vel_y: PBField
	func has_vel_y() -> bool:
		if __vel_y.value != null:
			return true
		return false
	func get_vel_y() -> float:
		return __vel_y.value
	func clear_vel_y() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__vel_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_vel_y(value : float) -> void:
		__vel_y.value = value
	
	var __vel_z: PBField
	func has_vel_z() -> bool:
		if __vel_z.value != null:
			return true
		return false
	func get_vel_z() -> float:
		return __vel_z.value
	func clear_vel_z() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__vel_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_vel_z(value : float) -> void:
		__vel_z.value = value
	
	var __rot_y: PBField
	func has_rot_y() -> bool:
		if __rot_y.value != null:
			return true
		return false
	func get_rot_y() -> float:
		return __rot_y.value
	func clear_rot_y() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__rot_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_rot_y(value : float) -> void:
		__rot_y.value = value
	
	var __active_impulse: PBField
	func has_active_impulse() -> bool:
		if __active_impulse.value != null:
			return true
		return false
	func get_active_impulse() -> Impulse:
		return __active_impulse.value
	func clear_active_impulse() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__active_impulse.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_active_impulse() -> Impulse:
		__active_impulse.value = Impulse.new()
		return __active_impulse.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class WorldDiff:
	func _init():
		var service
		
		__tick = PBField.new("tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __tick
		data[__tick.tag] = service
		
		var __entities_default: Array[EntityState] = []
		__entities = PBField.new("entities", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __entities_default)
		service = PBServiceField.new()
		service.field = __entities
		service.func_ref = Callable(self, "add_entities")
		data[__entities.tag] = service
		
	var data = {}
	
	var __tick: PBField
	func has_tick() -> bool:
		if __tick.value != null:
			return true
		return false
	func get_tick() -> int:
		return __tick.value
	func clear_tick() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_tick(value : int) -> void:
		__tick.value = value
	
	var __entities: PBField
	func get_entities() -> Array[EntityState]:
		return __entities.value
	func clear_entities() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__entities.value.clear()
	func add_entities() -> EntityState:
		var element = EntityState.new()
		__entities.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ClockPing:
	func _init():
		var service
		
		__ping_id = PBField.new("ping_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __ping_id
		data[__ping_id.tag] = service
		
		__client_time = PBField.new("client_time", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __client_time
		data[__client_time.tag] = service
		
	var data = {}
	
	var __ping_id: PBField
	func has_ping_id() -> bool:
		if __ping_id.value != null:
			return true
		return false
	func get_ping_id() -> int:
		return __ping_id.value
	func clear_ping_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ping_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_ping_id(value : int) -> void:
		__ping_id.value = value
	
	var __client_time: PBField
	func has_client_time() -> bool:
		if __client_time.value != null:
			return true
		return false
	func get_client_time() -> float:
		return __client_time.value
	func clear_client_time() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__client_time.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_client_time(value : float) -> void:
		__client_time.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ClockPong:
	func _init():
		var service
		
		__ping_id = PBField.new("ping_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __ping_id
		data[__ping_id.tag] = service
		
		__client_time = PBField.new("client_time", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __client_time
		data[__client_time.tag] = service
		
		__server_time = PBField.new("server_time", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __server_time
		data[__server_time.tag] = service
		
		__server_tick = PBField.new("server_tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __server_tick
		data[__server_tick.tag] = service
		
	var data = {}
	
	var __ping_id: PBField
	func has_ping_id() -> bool:
		if __ping_id.value != null:
			return true
		return false
	func get_ping_id() -> int:
		return __ping_id.value
	func clear_ping_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ping_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_ping_id(value : int) -> void:
		__ping_id.value = value
	
	var __client_time: PBField
	func has_client_time() -> bool:
		if __client_time.value != null:
			return true
		return false
	func get_client_time() -> float:
		return __client_time.value
	func clear_client_time() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__client_time.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_client_time(value : float) -> void:
		__client_time.value = value
	
	var __server_time: PBField
	func has_server_time() -> bool:
		if __server_time.value != null:
			return true
		return false
	func get_server_time() -> float:
		return __server_time.value
	func clear_server_time() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__server_time.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_server_time(value : float) -> void:
		__server_time.value = value
	
	var __server_tick: PBField
	func has_server_tick() -> bool:
		if __server_tick.value != null:
			return true
		return false
	func get_server_tick() -> int:
		return __server_tick.value
	func clear_server_tick() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_server_tick(value : int) -> void:
		__server_tick.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class InputBatch:
	func _init():
		var service
		
		var __inputs_default: Array[PlayerInput] = []
		__inputs = PBField.new("inputs", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __inputs_default)
		service = PBServiceField.new()
		service.field = __inputs
		service.func_ref = Callable(self, "add_inputs")
		data[__inputs.tag] = service
		
	var data = {}
	
	var __inputs: PBField
	func get_inputs() -> Array[PlayerInput]:
		return __inputs.value
	func clear_inputs() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__inputs.value.clear()
	func add_inputs() -> PlayerInput:
		var element = PlayerInput.new()
		__inputs.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ZoneRedirect:
	func _init():
		var service
		
		__zone_id = PBField.new("zone_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __zone_id
		data[__zone_id.tag] = service
		
		__address = PBField.new("address", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __address
		data[__address.tag] = service
		
		__port = PBField.new("port", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __port
		data[__port.tag] = service
		
		__transfer_token = PBField.new("transfer_token", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __transfer_token
		data[__transfer_token.tag] = service
		
	var data = {}
	
	var __zone_id: PBField
	func has_zone_id() -> bool:
		if __zone_id.value != null:
			return true
		return false
	func get_zone_id() -> String:
		return __zone_id.value
	func clear_zone_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__zone_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_zone_id(value : String) -> void:
		__zone_id.value = value
	
	var __address: PBField
	func has_address() -> bool:
		if __address.value != null:
			return true
		return false
	func get_address() -> String:
		return __address.value
	func clear_address() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_address(value : String) -> void:
		__address.value = value
	
	var __port: PBField
	func has_port() -> bool:
		if __port.value != null:
			return true
		return false
	func get_port() -> int:
		return __port.value
	func clear_port() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__port.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_port(value : int) -> void:
		__port.value = value
	
	var __transfer_token: PBField
	func has_transfer_token() -> bool:
		if __transfer_token.value != null:
			return true
		return false
	func get_transfer_token() -> String:
		return __transfer_token.value
	func clear_transfer_token() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__transfer_token.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_transfer_token(value : String) -> void:
		__transfer_token.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ZoneArrival:
	func _init():
		var service
		
		__transfer_token = PBField.new("transfer_token", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __transfer_token
		data[__transfer_token.tag] = service
		
	var data = {}
	
	var __transfer_token: PBField
	func has_transfer_token() -> bool:
		if __transfer_token.value != null:
			return true
		return false
	func get_transfer_token() -> String:
		return __transfer_token.value
	func clear_transfer_token() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__transfer_token.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_transfer_token(value : String) -> void:
		__transfer_token.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class PlayerState:
	func _init():
		var service
		
		__pos_x = PBField.new("pos_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __pos_x
		data[__pos_x.tag] = service
		
		__pos_y = PBField.new("pos_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __pos_y
		data[__pos_y.tag] = service
		
		__pos_z = PBField.new("pos_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __pos_z
		data[__pos_z.tag] = service
		
		__vel_x = PBField.new("vel_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __vel_x
		data[__vel_x.tag] = service
		
		__vel_y = PBField.new("vel_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __vel_y
		data[__vel_y.tag] = service
		
		__vel_z = PBField.new("vel_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __vel_z
		data[__vel_z.tag] = service
		
		__rot_y = PBField.new("rot_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __rot_y
		data[__rot_y.tag] = service
		
	var data = {}
	
	var __pos_x: PBField
	func has_pos_x() -> bool:
		if __pos_x.value != null:
			return true
		return false
	func get_pos_x() -> float:
		return __pos_x.value
	func clear_pos_x() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__pos_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_pos_x(value : float) -> void:
		__pos_x.value = value
	
	var __pos_y: PBField
	func has_pos_y() -> bool:
		if __pos_y.value != null:
			return true
		return false
	func get_pos_y() -> float:
		return __pos_y.value
	func clear_pos_y() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__pos_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_pos_y(value : float) -> void:
		__pos_y.value = value
	
	var __pos_z: PBField
	func has_pos_z() -> bool:
		if __pos_z.value != null:
			return true
		return false
	func get_pos_z() -> float:
		return __pos_z.value
	func clear_pos_z() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__pos_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_pos_z(value : float) -> void:
		__pos_z.value = value
	
	var __vel_x: PBField
	func has_vel_x() -> bool:
		if __vel_x.value != null:
			return true
		return false
	func get_vel_x() -> float:
		return __vel_x.value
	func clear_vel_x() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__vel_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_vel_x(value : float) -> void:
		__vel_x.value = value
	
	var __vel_y: PBField
	func has_vel_y() -> bool:
		if __vel_y.value != null:
			return true
		return false
	func get_vel_y() -> float:
		return __vel_y.value
	func clear_vel_y() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__vel_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_vel_y(value : float) -> void:
		__vel_y.value = value
	
	var __vel_z: PBField
	func has_vel_z() -> bool:
		if __vel_z.value != null:
			return true
		return false
	func get_vel_z() -> float:
		return __vel_z.value
	func clear_vel_z() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__vel_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_vel_z(value : float) -> void:
		__vel_z.value = value
	
	var __rot_y: PBField
	func has_rot_y() -> bool:
		if __rot_y.value != null:
			return true
		return false
	func get_rot_y() -> float:
		return __rot_y.value
	func clear_rot_y() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__rot_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_rot_y(value : float) -> void:
		__rot_y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ZoneRegister:
	func _init():
		var service
		
		__zone_id = PBField.new("zone_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __zone_id
		data[__zone_id.tag] = service
		
		__address = PBField.new("address", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __address
		data[__address.tag] = service
		
		__port = PBField.new("port", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __port
		data[__port.tag] = service
		
		__max_players = PBField.new("max_players", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __max_players
		data[__max_players.tag] = service
		
		__current_players = PBField.new("current_players", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __current_players
		data[__current_players.tag] = service
		
	var data = {}
	
	var __zone_id: PBField
	func has_zone_id() -> bool:
		if __zone_id.value != null:
			return true
		return false
	func get_zone_id() -> String:
		return __zone_id.value
	func clear_zone_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__zone_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_zone_id(value : String) -> void:
		__zone_id.value = value
	
	var __address: PBField
	func has_address() -> bool:
		if __address.value != null:
			return true
		return false
	func get_address() -> String:
		return __address.value
	func clear_address() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_address(value : String) -> void:
		__address.value = value
	
	var __port: PBField
	func has_port() -> bool:
		if __port.value != null:
			return true
		return false
	func get_port() -> int:
		return __port.value
	func clear_port() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__port.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_port(value : int) -> void:
		__port.value = value
	
	var __max_players: PBField
	func has_max_players() -> bool:
		if __max_players.value != null:
			return true
		return false
	func get_max_players() -> int:
		return __max_players.value
	func clear_max_players() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__max_players.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_max_players(value : int) -> void:
		__max_players.value = value
	
	var __current_players: PBField
	func has_current_players() -> bool:
		if __current_players.value != null:
			return true
		return false
	func get_current_players() -> int:
		return __current_players.value
	func clear_current_players() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__current_players.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_current_players(value : int) -> void:
		__current_players.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ZoneTransferRequest:
	func _init():
		var service
		
		__peer_id = PBField.new("peer_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __peer_id
		data[__peer_id.tag] = service
		
		__from_zone_id = PBField.new("from_zone_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __from_zone_id
		data[__from_zone_id.tag] = service
		
		__to_zone_id = PBField.new("to_zone_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __to_zone_id
		data[__to_zone_id.tag] = service
		
		__player_state = PBField.new("player_state", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __player_state
		service.func_ref = Callable(self, "new_player_state")
		data[__player_state.tag] = service
		
		__entry_x = PBField.new("entry_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __entry_x
		data[__entry_x.tag] = service
		
		__entry_y = PBField.new("entry_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __entry_y
		data[__entry_y.tag] = service
		
		__entry_z = PBField.new("entry_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __entry_z
		data[__entry_z.tag] = service
		
		__entry_rot_y = PBField.new("entry_rot_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __entry_rot_y
		data[__entry_rot_y.tag] = service
		
	var data = {}
	
	var __peer_id: PBField
	func has_peer_id() -> bool:
		if __peer_id.value != null:
			return true
		return false
	func get_peer_id() -> int:
		return __peer_id.value
	func clear_peer_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__peer_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_peer_id(value : int) -> void:
		__peer_id.value = value
	
	var __from_zone_id: PBField
	func has_from_zone_id() -> bool:
		if __from_zone_id.value != null:
			return true
		return false
	func get_from_zone_id() -> String:
		return __from_zone_id.value
	func clear_from_zone_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__from_zone_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_from_zone_id(value : String) -> void:
		__from_zone_id.value = value
	
	var __to_zone_id: PBField
	func has_to_zone_id() -> bool:
		if __to_zone_id.value != null:
			return true
		return false
	func get_to_zone_id() -> String:
		return __to_zone_id.value
	func clear_to_zone_id() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__to_zone_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_to_zone_id(value : String) -> void:
		__to_zone_id.value = value
	
	var __player_state: PBField
	func has_player_state() -> bool:
		if __player_state.value != null:
			return true
		return false
	func get_player_state() -> PlayerState:
		return __player_state.value
	func clear_player_state() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__player_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_player_state() -> PlayerState:
		__player_state.value = PlayerState.new()
		return __player_state.value
	
	var __entry_x: PBField
	func has_entry_x() -> bool:
		if __entry_x.value != null:
			return true
		return false
	func get_entry_x() -> float:
		return __entry_x.value
	func clear_entry_x() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__entry_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_entry_x(value : float) -> void:
		__entry_x.value = value
	
	var __entry_y: PBField
	func has_entry_y() -> bool:
		if __entry_y.value != null:
			return true
		return false
	func get_entry_y() -> float:
		return __entry_y.value
	func clear_entry_y() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__entry_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_entry_y(value : float) -> void:
		__entry_y.value = value
	
	var __entry_z: PBField
	func has_entry_z() -> bool:
		if __entry_z.value != null:
			return true
		return false
	func get_entry_z() -> float:
		return __entry_z.value
	func clear_entry_z() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__entry_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_entry_z(value : float) -> void:
		__entry_z.value = value
	
	var __entry_rot_y: PBField
	func has_entry_rot_y() -> bool:
		if __entry_rot_y.value != null:
			return true
		return false
	func get_entry_rot_y() -> float:
		return __entry_rot_y.value
	func clear_entry_rot_y() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__entry_rot_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_entry_rot_y(value : float) -> void:
		__entry_rot_y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class PreparePlayer:
	func _init():
		var service
		
		__transfer_token = PBField.new("transfer_token", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __transfer_token
		data[__transfer_token.tag] = service
		
		__player_state = PBField.new("player_state", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __player_state
		service.func_ref = Callable(self, "new_player_state")
		data[__player_state.tag] = service
		
		__entry_x = PBField.new("entry_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __entry_x
		data[__entry_x.tag] = service
		
		__entry_y = PBField.new("entry_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __entry_y
		data[__entry_y.tag] = service
		
		__entry_z = PBField.new("entry_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __entry_z
		data[__entry_z.tag] = service
		
		__entry_rot_y = PBField.new("entry_rot_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __entry_rot_y
		data[__entry_rot_y.tag] = service
		
	var data = {}
	
	var __transfer_token: PBField
	func has_transfer_token() -> bool:
		if __transfer_token.value != null:
			return true
		return false
	func get_transfer_token() -> String:
		return __transfer_token.value
	func clear_transfer_token() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__transfer_token.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_transfer_token(value : String) -> void:
		__transfer_token.value = value
	
	var __player_state: PBField
	func has_player_state() -> bool:
		if __player_state.value != null:
			return true
		return false
	func get_player_state() -> PlayerState:
		return __player_state.value
	func clear_player_state() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__player_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_player_state() -> PlayerState:
		__player_state.value = PlayerState.new()
		return __player_state.value
	
	var __entry_x: PBField
	func has_entry_x() -> bool:
		if __entry_x.value != null:
			return true
		return false
	func get_entry_x() -> float:
		return __entry_x.value
	func clear_entry_x() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__entry_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_entry_x(value : float) -> void:
		__entry_x.value = value
	
	var __entry_y: PBField
	func has_entry_y() -> bool:
		if __entry_y.value != null:
			return true
		return false
	func get_entry_y() -> float:
		return __entry_y.value
	func clear_entry_y() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__entry_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_entry_y(value : float) -> void:
		__entry_y.value = value
	
	var __entry_z: PBField
	func has_entry_z() -> bool:
		if __entry_z.value != null:
			return true
		return false
	func get_entry_z() -> float:
		return __entry_z.value
	func clear_entry_z() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__entry_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_entry_z(value : float) -> void:
		__entry_z.value = value
	
	var __entry_rot_y: PBField
	func has_entry_rot_y() -> bool:
		if __entry_rot_y.value != null:
			return true
		return false
	func get_entry_rot_y() -> float:
		return __entry_rot_y.value
	func clear_entry_rot_y() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__entry_rot_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_entry_rot_y(value : float) -> void:
		__entry_rot_y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class PreparePlayerAck:
	func _init():
		var service
		
		__transfer_token = PBField.new("transfer_token", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __transfer_token
		data[__transfer_token.tag] = service
		
		__accepted = PBField.new("accepted", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __accepted
		data[__accepted.tag] = service
		
	var data = {}
	
	var __transfer_token: PBField
	func has_transfer_token() -> bool:
		if __transfer_token.value != null:
			return true
		return false
	func get_transfer_token() -> String:
		return __transfer_token.value
	func clear_transfer_token() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__transfer_token.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_transfer_token(value : String) -> void:
		__transfer_token.value = value
	
	var __accepted: PBField
	func has_accepted() -> bool:
		if __accepted.value != null:
			return true
		return false
	func get_accepted() -> bool:
		return __accepted.value
	func clear_accepted() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_accepted(value : bool) -> void:
		__accepted.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ZoneTransferResponse:
	func _init():
		var service
		
		__peer_id = PBField.new("peer_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __peer_id
		data[__peer_id.tag] = service
		
		__transfer_token = PBField.new("transfer_token", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __transfer_token
		data[__transfer_token.tag] = service
		
		__target_address = PBField.new("target_address", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __target_address
		data[__target_address.tag] = service
		
		__target_port = PBField.new("target_port", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __target_port
		data[__target_port.tag] = service
		
		__zone_id = PBField.new("zone_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __zone_id
		data[__zone_id.tag] = service
		
	var data = {}
	
	var __peer_id: PBField
	func has_peer_id() -> bool:
		if __peer_id.value != null:
			return true
		return false
	func get_peer_id() -> int:
		return __peer_id.value
	func clear_peer_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__peer_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_peer_id(value : int) -> void:
		__peer_id.value = value
	
	var __transfer_token: PBField
	func has_transfer_token() -> bool:
		if __transfer_token.value != null:
			return true
		return false
	func get_transfer_token() -> String:
		return __transfer_token.value
	func clear_transfer_token() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__transfer_token.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_transfer_token(value : String) -> void:
		__transfer_token.value = value
	
	var __target_address: PBField
	func has_target_address() -> bool:
		if __target_address.value != null:
			return true
		return false
	func get_target_address() -> String:
		return __target_address.value
	func clear_target_address() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__target_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_target_address(value : String) -> void:
		__target_address.value = value
	
	var __target_port: PBField
	func has_target_port() -> bool:
		if __target_port.value != null:
			return true
		return false
	func get_target_port() -> int:
		return __target_port.value
	func clear_target_port() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__target_port.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_target_port(value : int) -> void:
		__target_port.value = value
	
	var __zone_id: PBField
	func has_zone_id() -> bool:
		if __zone_id.value != null:
			return true
		return false
	func get_zone_id() -> String:
		return __zone_id.value
	func clear_zone_id() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_zone_id(value : String) -> void:
		__zone_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Packet:
	func _init():
		var service
		
		__player_input = PBField.new("player_input", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __player_input
		service.func_ref = Callable(self, "new_player_input")
		data[__player_input.tag] = service
		
		__world_diff = PBField.new("world_diff", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __world_diff
		service.func_ref = Callable(self, "new_world_diff")
		data[__world_diff.tag] = service
		
		__clock_ping = PBField.new("clock_ping", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __clock_ping
		service.func_ref = Callable(self, "new_clock_ping")
		data[__clock_ping.tag] = service
		
		__clock_pong = PBField.new("clock_pong", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __clock_pong
		service.func_ref = Callable(self, "new_clock_pong")
		data[__clock_pong.tag] = service
		
		__input_batch = PBField.new("input_batch", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __input_batch
		service.func_ref = Callable(self, "new_input_batch")
		data[__input_batch.tag] = service
		
		__zone_redirect = PBField.new("zone_redirect", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __zone_redirect
		service.func_ref = Callable(self, "new_zone_redirect")
		data[__zone_redirect.tag] = service
		
		__zone_arrival = PBField.new("zone_arrival", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __zone_arrival
		service.func_ref = Callable(self, "new_zone_arrival")
		data[__zone_arrival.tag] = service
		
	var data = {}
	
	var __player_input: PBField
	func has_player_input() -> bool:
		if __player_input.value != null:
			return true
		return false
	func get_player_input() -> PlayerInput:
		return __player_input.value
	func clear_player_input() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_player_input() -> PlayerInput:
		data[1].state = PB_SERVICE_STATE.FILLED
		__world_diff.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__player_input.value = PlayerInput.new()
		return __player_input.value
	
	var __world_diff: PBField
	func has_world_diff() -> bool:
		if __world_diff.value != null:
			return true
		return false
	func get_world_diff() -> WorldDiff:
		return __world_diff.value
	func clear_world_diff() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__world_diff.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_world_diff() -> WorldDiff:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		data[2].state = PB_SERVICE_STATE.FILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__world_diff.value = WorldDiff.new()
		return __world_diff.value
	
	var __clock_ping: PBField
	func has_clock_ping() -> bool:
		if __clock_ping.value != null:
			return true
		return false
	func get_clock_ping() -> ClockPing:
		return __clock_ping.value
	func clear_clock_ping() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_clock_ping() -> ClockPing:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__world_diff.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		data[3].state = PB_SERVICE_STATE.FILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = ClockPing.new()
		return __clock_ping.value
	
	var __clock_pong: PBField
	func has_clock_pong() -> bool:
		if __clock_pong.value != null:
			return true
		return false
	func get_clock_pong() -> ClockPong:
		return __clock_pong.value
	func clear_clock_pong() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_clock_pong() -> ClockPong:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__world_diff.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		data[4].state = PB_SERVICE_STATE.FILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = ClockPong.new()
		return __clock_pong.value
	
	var __input_batch: PBField
	func has_input_batch() -> bool:
		if __input_batch.value != null:
			return true
		return false
	func get_input_batch() -> InputBatch:
		return __input_batch.value
	func clear_input_batch() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_input_batch() -> InputBatch:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__world_diff.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		data[5].state = PB_SERVICE_STATE.FILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = InputBatch.new()
		return __input_batch.value
	
	var __zone_redirect: PBField
	func has_zone_redirect() -> bool:
		if __zone_redirect.value != null:
			return true
		return false
	func get_zone_redirect() -> ZoneRedirect:
		return __zone_redirect.value
	func clear_zone_redirect() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_zone_redirect() -> ZoneRedirect:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__world_diff.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		data[6].state = PB_SERVICE_STATE.FILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = ZoneRedirect.new()
		return __zone_redirect.value
	
	var __zone_arrival: PBField
	func has_zone_arrival() -> bool:
		if __zone_arrival.value != null:
			return true
		return false
	func get_zone_arrival() -> ZoneArrival:
		return __zone_arrival.value
	func clear_zone_arrival() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_zone_arrival() -> ZoneArrival:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__world_diff.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		data[7].state = PB_SERVICE_STATE.FILLED
		__zone_arrival.value = ZoneArrival.new()
		return __zone_arrival.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class OrchestratorPacket:
	func _init():
		var service
		
		__zone_register = PBField.new("zone_register", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __zone_register
		service.func_ref = Callable(self, "new_zone_register")
		data[__zone_register.tag] = service
		
		__zone_transfer_request = PBField.new("zone_transfer_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __zone_transfer_request
		service.func_ref = Callable(self, "new_zone_transfer_request")
		data[__zone_transfer_request.tag] = service
		
		__prepare_player = PBField.new("prepare_player", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __prepare_player
		service.func_ref = Callable(self, "new_prepare_player")
		data[__prepare_player.tag] = service
		
		__prepare_player_ack = PBField.new("prepare_player_ack", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __prepare_player_ack
		service.func_ref = Callable(self, "new_prepare_player_ack")
		data[__prepare_player_ack.tag] = service
		
		__zone_transfer_response = PBField.new("zone_transfer_response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __zone_transfer_response
		service.func_ref = Callable(self, "new_zone_transfer_response")
		data[__zone_transfer_response.tag] = service
		
	var data = {}
	
	var __zone_register: PBField
	func has_zone_register() -> bool:
		if __zone_register.value != null:
			return true
		return false
	func get_zone_register() -> ZoneRegister:
		return __zone_register.value
	func clear_zone_register() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__zone_register.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_zone_register() -> ZoneRegister:
		data[1].state = PB_SERVICE_STATE.FILLED
		__zone_transfer_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_register.value = ZoneRegister.new()
		return __zone_register.value
	
	var __zone_transfer_request: PBField
	func has_zone_transfer_request() -> bool:
		if __zone_transfer_request.value != null:
			return true
		return false
	func get_zone_transfer_request() -> ZoneTransferRequest:
		return __zone_transfer_request.value
	func clear_zone_transfer_request() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_zone_transfer_request() -> ZoneTransferRequest:
		__zone_register.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		data[2].state = PB_SERVICE_STATE.FILLED
		__prepare_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_request.value = ZoneTransferRequest.new()
		return __zone_transfer_request.value
	
	var __prepare_player: PBField
	func has_prepare_player() -> bool:
		if __prepare_player.value != null:
			return true
		return false
	func get_prepare_player() -> PreparePlayer:
		return __prepare_player.value
	func clear_prepare_player() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_prepare_player() -> PreparePlayer:
		__zone_register.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		data[3].state = PB_SERVICE_STATE.FILLED
		__prepare_player_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player.value = PreparePlayer.new()
		return __prepare_player.value
	
	var __prepare_player_ack: PBField
	func has_prepare_player_ack() -> bool:
		if __prepare_player_ack.value != null:
			return true
		return false
	func get_prepare_player_ack() -> PreparePlayerAck:
		return __prepare_player_ack.value
	func clear_prepare_player_ack() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_prepare_player_ack() -> PreparePlayerAck:
		__zone_register.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		data[4].state = PB_SERVICE_STATE.FILLED
		__zone_transfer_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player_ack.value = PreparePlayerAck.new()
		return __prepare_player_ack.value
	
	var __zone_transfer_response: PBField
	func has_zone_transfer_response() -> bool:
		if __zone_transfer_response.value != null:
			return true
		return false
	func get_zone_transfer_response() -> ZoneTransferResponse:
		return __zone_transfer_response.value
	func clear_zone_transfer_response() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_zone_transfer_response() -> ZoneTransferResponse:
		__zone_register.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		data[5].state = PB_SERVICE_STATE.FILLED
		__zone_transfer_response.value = ZoneTransferResponse.new()
		return __zone_transfer_response.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
################ USER DATA END #################
