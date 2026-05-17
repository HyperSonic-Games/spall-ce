package main

import "core:bytes"
import "core:slice"
import "core:math"
import "core:mem"
import "core:strings"
import "core:fmt"

// PDB is complete nonsense. 
// At the bottom of the PDB header is an array of offsets. The array of offsets get you blocks, containing offsets.
// *THOSE* offsets get you the blocks containing the data to figure out what your data is.

PDB_MAGIC := []u8{
	'M', 'i', 'c', 'r', 'o', 's', 'o', 'f', 't', ' ', 'C', '/', 'C', '+', '+',
	' ', 'M', 'S', 'F', ' ', '7', '.', '0', '0', '\r', '\n', 0x1A, 0x44, 0x53, 0, 0, 0,
}

INFO_STREAM_IDX :: 1
DBI_STREAM_IDX  :: 3

PDB_V70  :: 19990903
PDB_VC70 :: 20000404

PDB_MSF_Header :: struct #packed {
	magic:           [32]u8,
	block_size:         u32,
	free_block_map_idx: u32,
	block_count:        u32,
	directory_size:     u32,
	reserved:           u32,
}

PDB_DBI_Header :: struct #packed {
	signature:                  i32,
	version:                    u32,
	age:                        u32,
	global_stream_idx:          u16,
	build_idx:                  u16,
	public_stream_idx:          u16,
	pdb_dll_version:            u16,
	sym_record_stream:          u16,
	pdb_dll_rebuild:            u16,
	mod_info_size:              i32,
	section_contrib_size:       i32,
	section_map_size:           i32,
	source_info_size:           i32,
	type_server_size:           i32,
	mfc_type_server_idx:        u32,
	optional_debug_header_size: i32,
	ec_subsystem_size:          i32,
	flags:                      u16,
	machine:                    u16,
	pad:                        u32,
}

PDB_Info_Stream_Header :: struct #packed {
	version:   u32,
	signature: u32,
	age:       u32,
	guid:   [16]u8,
}

PDB_HashTable_Header :: struct #packed {
	size: u32,
	capacity: u32,
}

PDB_HashTable_Entry :: struct #packed {
	string_offset: u32,
	stream_idx: u32,
}

PDB_Names_Header :: struct #packed {
	magic: u32,
	hash_version: u32,
	size: u32,
}

PDB_Section_Contrib_Entry :: struct #packed {
	section:    u16,
	padding:  [2]u8,
	offset:     i32,
	size:       i32,
	flags:      u32,
	module_idx: u16,
	padding2: [2]u8,
	data_crc:   u32,
	reloc_crc:  u32,
}

CV_Symbol_Type :: enum u16 {
	GlobalProc32 = 0x1110,
	LocalProc32  = 0x110f,
}

PDB_Symbol_Header :: struct #packed {
	length: u16,
	type: CV_Symbol_Type,
}

PDB_Module_Info :: struct #packed {
	reserved:             u32,
	section_contrib:      PDB_Section_Contrib_Entry,
	flags:                u16,
	module_symbol_stream: u16,
	symbols_size:         u32,
	c11_size:             u32,
	c13_size:             u32,
	source_file_count:    u16,
	padding:            [2]u8,
	reserved2:            u32,
	source_file_name_idx: u32,
	file_path_name_idx:   u32,
}

CV_Proc32 :: struct #packed {
	record_length:    u16,
	record_type:      u16,
	parent_offset:    u32,
	block_end_offset: u32,
	next_offset:      u32,
	proc_length:      u32,
	dbg_start_offset: u32,
	dbg_end_offset:   u32,
	type_id:          u32,
	offset:           u32,
	section_idx:      u16,
	flags:             u8,
}

PDB_Debug_Subsection_Type :: enum u32 {
	Ignore            =    0,
	Symbols           = 0xF1,
	Lines             = 0xF2,
	StringTable       = 0xF3,
	FileChecksums     = 0xF4,
	FrameData         = 0xF5,
	InlineLines       = 0xF6,
	CrossScopeImports = 0xF7,
	CrossScopeExports = 0xF8,
	InlineLinesEx     = 0xF9,
	FuncMDTokenMap    = 0xFA,
	TypeMDTokenMap    = 0xFB,
	MergedAsmInput    = 0xFC,
	COFFSymbolRva     = 0xFD,
}

PDB_Debug_Subsection_Header :: struct #packed {
	type: PDB_Debug_Subsection_Type,
	length: u32,
}

PDB_Line :: struct #packed {
	offset: u32,
	things: u32,
}

PDB_Line_Header :: struct #packed {
	offset:      u32,
	index:       u16,
	has_columns: u16,
	code_size:   u32,
}
PDB_Line_File_Block_Header :: struct #packed {
	file_checksum_offset: u32,
	line_count: u32,
	size: u32,
}

PDB_Inline_Line_Type :: enum u32 {
	Signature   = 0,
	SignatureEx = 1,
}
PDB_Inline_Line_Header :: struct #packed {
	type: PDB_Inline_Line_Type,
}
PDB_Inline_Line :: struct #packed {
	type: PDB_Inline_Line_Type,
	inlinee: u32,
	file_checksum_offset: u32,
	line_header: u32,
}
PDB_Inline_Line_Ex :: struct #packed {
	type: PDB_Inline_Line_Type,
	inlinee: u32,
	file_checksum_offset: u32,
	line_header: u32,
	extra_lines: u32,
}

PDB_File_Checksum_Header :: struct #packed {
	filename_offset: u32,
	checksum_size:    u8,
	checksum_type:    u8,
}

Line :: struct {
	address: u64,
	file_idx: u32,
	number: u32,
	_inline: bool,
}

load_pdb :: proc(trace: ^Trace, section_buffer: []u8, pdb_buffer: []u8, bucket: ^Func_Bucket) -> bool {
	msf_hdr := slice_to_type(pdb_buffer, PDB_MSF_Header) or_return
	if !bytes.equal(msf_hdr.magic[:], PDB_MAGIC) {
		return false
	}

	directory_block_count := div_ceil(msf_hdr.directory_size, msf_hdr.block_size)
	msf_end_buffer := pdb_buffer[size_of(PDB_MSF_Header):][:directory_block_count * size_of(u32)]
	directory_block_offsets := slice.reinterpret([]u32, msf_end_buffer)
	directory_offsets := slice.reinterpret([]u32, linearize_stream(pdb_buffer, directory_block_offsets, msf_hdr.block_size, directory_block_count * size_of(u32)))
	defer delete(directory_offsets) 
	directory_stream  := slice.reinterpret([]u32, linearize_stream(pdb_buffer, directory_offsets, msf_hdr.block_size, msf_hdr.directory_size))
	defer delete(directory_stream) 

	stream_count  := directory_stream[0]
	stream_sizes  := directory_stream[1:1+stream_count]
	stream_blocks := directory_stream[1+stream_count:]
	
	// This is the offset into the stream directory. Each one points to the list of blocks that make up a stream
	stream_block_offsets := make([]u32, stream_count)
	defer delete(stream_block_offsets)
	offset_into_stream_blocks : u32 = 0
	for i := 0; i < len(stream_sizes); i += 1 {
		stream_block_count := div_ceil(stream_sizes[i], msf_hdr.block_size)
		stream_block_offsets[i] = offset_into_stream_blocks
		offset_into_stream_blocks += stream_block_count
	}

	info_stream_offset := stream_block_offsets[INFO_STREAM_IDX]
	info_stream_size := stream_sizes[INFO_STREAM_IDX]
	info_stream_offset_stream := stream_blocks[info_stream_offset:]
	info_stream := linearize_stream(pdb_buffer, info_stream_offset_stream, msf_hdr.block_size, info_stream_size)
	defer delete(info_stream) 

	info_offset := 0
	info_hdr := slice_to_type(info_stream, PDB_Info_Stream_Header) or_return
	if info_hdr.version != PDB_VC70 {
		return false
	}
	info_offset += size_of(PDB_Info_Stream_Header)

	string_buffer_length := slice_to_type(info_stream[info_offset:], u32) or_return
	info_offset += size_of(u32)
	string_buffer := info_stream[info_offset:][:string_buffer_length]
	info_offset += int(string_buffer_length)

	hash_hdr := slice_to_type(info_stream[info_offset:], PDB_HashTable_Header) or_return
	info_offset += size_of(PDB_HashTable_Header)

	present_count := slice_to_type(info_stream[info_offset:], u32) or_return
	info_offset += size_of(u32)
	info_offset += int(present_count) * size_of(u32)

	deleted_count := slice_to_type(info_stream[info_offset:], u32) or_return
	info_offset += size_of(u32)
	info_offset += int(deleted_count) * size_of(u32)

	name_stream_idx := -1
	for i : uint = 0; i < uint(hash_hdr.size); i += 1 {
		entry := slice_to_type(info_stream[info_offset:], PDB_HashTable_Entry) or_return
		name := cstring(raw_data(string_buffer[entry.string_offset:]))
		if name == "/names" {
			name_stream_idx = int(entry.stream_idx)
			break
		}
		info_offset += size_of(PDB_HashTable_Entry)
	}
	if name_stream_idx == -1 {
		return false
	}

	name_stream_offset := stream_block_offsets[name_stream_idx]
	name_stream_size := stream_sizes[name_stream_idx]
	name_offset_stream := stream_blocks[name_stream_offset:]
	name_stream := linearize_stream(pdb_buffer, name_offset_stream, msf_hdr.block_size, name_stream_size)
	defer delete(name_stream)
	name_stream_strings := name_stream[size_of(PDB_Names_Header):]

	dbi_offset := stream_block_offsets[DBI_STREAM_IDX]
	dbi_stream_size := stream_sizes[DBI_STREAM_IDX]
	dbi_offset_stream := stream_blocks[dbi_offset:]
	dbi_stream := linearize_stream(pdb_buffer, dbi_offset_stream, msf_hdr.block_size, dbi_stream_size)
	defer delete(dbi_stream)

	dbi_hdr := slice_to_type(dbi_stream, PDB_DBI_Header) or_return
	if dbi_hdr.version != PDB_V70 {
		return false
	}

	mod_offset := size_of(PDB_DBI_Header)
	last_mod_info := int(dbi_hdr.mod_info_size) + size_of(PDB_DBI_Header)
	for ; mod_offset < last_mod_info; {
		mod_info_hdr := slice_to_type(dbi_stream[mod_offset:], PDB_Module_Info) or_return
		mod_offset += size_of(PDB_Module_Info)

		module_name := cstring(raw_data(dbi_stream[mod_offset:]))
		mod_name_sz := len(module_name) + 1
		mod_offset += mod_name_sz

		object_name := cstring(raw_data(dbi_stream[mod_offset:]))
		obj_name_sz := len(object_name) + 1
		mod_offset += obj_name_sz

		mod_offset = i_round_up(mod_offset, 4)

		// Skip over modules with no symbols
		if mod_info_hdr.module_symbol_stream == max(u16) {
			continue
		}

		symbol_offset_stream_offset := stream_block_offsets[mod_info_hdr.module_symbol_stream]
		symbol_stream_size := stream_sizes[mod_info_hdr.module_symbol_stream]
		symbol_offset_stream := stream_blocks[symbol_offset_stream_offset:]

		symbol_stream := linearize_stream(pdb_buffer, symbol_offset_stream, msf_hdr.block_size, symbol_stream_size)
		defer delete(symbol_stream)

		// skipping over codeview signature
		cur_offset := 4
		for ; cur_offset < (int(mod_info_hdr.symbols_size) - 2); {
			sym_hdr := slice_to_type(symbol_stream[cur_offset:], PDB_Symbol_Header) or_return
			#partial switch sym_hdr.type {
				case .GlobalProc32: fallthrough
				case .LocalProc32: {
					proc_symbol := slice_to_type(symbol_stream[cur_offset:], CV_Proc32) or_return
					symbol_name := string(cstring(raw_data(symbol_stream[cur_offset+size_of(CV_Proc32):])))

					sect_base_addr := base_address_for_section(section_buffer, proc_symbol.section_idx - 1) or_return

					low_pc := sect_base_addr + u64(proc_symbol.offset)
					high_pc := low_pc + u64(proc_symbol.proc_length)
					sym_idx := in_get(&trace.intern, &trace.string_block, symbol_name)
					add_func(bucket, sym_idx, low_pc, high_pc, 0)
				}
			}

			cur_offset += 2 + int(sym_hdr.length)
		}

		cur_end := int(mod_info_hdr.symbols_size) + int(mod_info_hdr.c11_size) + int(mod_info_hdr.c13_size)
		cur_offset += int(mod_info_hdr.c11_size)
		cur_start := cur_offset

		// Find the checksums
		checksum_pile: []u8
		for ; cur_offset < cur_end; {
			dbg_hdr := slice_to_type(symbol_stream[cur_offset:], PDB_Debug_Subsection_Header)
			cur_offset += size_of(PDB_Debug_Subsection_Header)
			end_offset := cur_offset + int(dbg_hdr.length)

			#partial switch dbg_hdr.type {
				case .FileChecksums: {
					checksum_pile = symbol_stream[cur_offset:]
				}
			}

			cur_offset = end_offset
		}

		cur_offset = cur_start
		for ; cur_offset < cur_end; {
			dbg_hdr := slice_to_type(symbol_stream[cur_offset:], PDB_Debug_Subsection_Header)
			cur_offset += size_of(PDB_Debug_Subsection_Header)
			end_offset := cur_offset + int(dbg_hdr.length)

			#partial switch dbg_hdr.type {
				case .Lines: {
					lines_hdr := slice_to_type(symbol_stream[cur_offset:], PDB_Line_Header)
					sect_base_addr := base_address_for_section(section_buffer, lines_hdr.index - 1) or_return
					line_addr := sect_base_addr + u64(lines_hdr.offset)
					cur_offset += size_of(PDB_Line_Header)

					for lfb_count := 0; cur_offset < end_offset; lfb_count += 1 {
						lfb_hdr := slice_to_type(symbol_stream[cur_offset:], PDB_Line_File_Block_Header) or_return
						lfb_end_offset := cur_offset + int(lfb_hdr.size)
						checksum_offset := lfb_hdr.file_checksum_offset

						cur_offset += size_of(PDB_Line_File_Block_Header)
						for i := 0; i < int(lfb_hdr.line_count); i += 1 {
							line := slice_to_type(symbol_stream[cur_offset:], PDB_Line) or_return
							line_num := (line.things << 8) >> 8

							checksum_hdr := slice_to_type(checksum_pile[checksum_offset:], PDB_File_Checksum_Header) or_return
							file_name := string(cstring(raw_data(name_stream_strings[checksum_hdr.filename_offset:])))
							interned_name, err := strings.intern_get(&trace.filename_map, file_name)
							if err != nil {
								panic("Out of Memory!\n")
							}

							add_line_info(bucket, line_addr + u64(line.offset), u64(line_num), interned_name)

							cur_offset += size_of(PDB_Line)
						}

						cur_offset = lfb_end_offset
					}
				}
				case .InlineLines: {
					inline_lines_hdr := slice_to_type(symbol_stream[cur_offset:], PDB_Inline_Line_Header)
					#partial switch inline_lines_hdr.type {
						case .Signature: {
							inline_line := slice_to_type(symbol_stream[cur_offset:], PDB_Inline_Line)
						}
					}
				}
			}

			cur_offset = end_offset
		}
	}

	line_order :: proc(a, b: Line_Info) -> bool {
		return a.address < b.address
	}
	slice.sort_by(bucket.line_info[:], line_order)

	fmt.printf("PDB: sorting functions\n")
	slice.sort_by(bucket.functions[:], func_order)
	build_scopes(trace, bucket)

	return true
}

base_address_for_section :: proc(section_buffer: []u8, idx: u16) -> (u64, bool) {
	section_offset := idx * size_of(COFF_Section_Header)
	section_hdr, ok := slice_to_type(section_buffer[section_offset:], COFF_Section_Header)
	if !ok {
		return 0, false
	}

	return u64(section_hdr.virtual_addr), true
}

linearize_stream :: proc(data: []u8, indices: []u32, block_size: u32, stream_size: u32, loc := #caller_location) -> []u8 {
	block_count := div_ceil(stream_size, block_size)
	linear_space := make([]u8, block_count * block_size)

	full_block_count, leftovers := math.divmod(stream_size, block_size)

	copy_offset : u32 = 0
	for i : u32 = 0; i < full_block_count; i += 1 {
		data_offset := indices[i] * block_size
		mem.copy_non_overlapping(raw_data(linear_space[copy_offset:]), raw_data(data[data_offset:]), int(block_size))
		copy_offset += block_size
	}

	if leftovers > 0 {
		data_offset := indices[block_count - 1] * block_size
		mem.copy_non_overlapping(raw_data(linear_space[copy_offset:]), raw_data(data[data_offset:]), int(leftovers))
	}

	return linear_space
}
