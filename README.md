# TranSh - Transaction Shell

## Overview

**TranSh** is a transaction-based shell interpreter designed to manage and execute complex transactions within a file system environment. It provides a specialized command-line interface that handles transaction operations, resource management, and multi-platform support (Linux and Solaris).

## What It Does

TranSh is a specialized shell that extends traditional command-line functionality with transaction management capabilities. Key features include:

- **Transaction Management**: Execute operations as atomic transactions with support for commit and rollback operations
- **File Operations**: Comprehensive file manipulation within a transaction context
- **Block-level Operations**: Handle block-level data structures and operations
- **Resource Tracking**: Track and manage system resources efficiently
- **Multi-platform Support**: Compatible with both Linux and Solaris platforms
- **Lexical Analysis**: Uses LEX (flex) for tokenization and parsing
- **Syntax Parsing**: Uses YACC (bison) for grammar parsing and AST construction

## How It Works

### Architecture

TranSh is built with the following modular components:

1. **Lexical Analysis** (`lex.yy.c`)
   - Tokenizes input using LEX/Flex
   - Converts raw shell commands into tokens
   - Handles multi-character operators and keywords

2. **Parser** (`TranSh.tab.c`)
   - Uses YACC/Bison for syntax analysis
   - Builds abstract syntax trees (AST)
   - Validates command grammar and structure

3. **Core Modules**:
   - **main.c** - Main entry point and shell loop
   - **tran.c** - Transaction management engine
   - **file.c** - File operation handling
   - **block.c** - Block-level data structure operations
   - **list.c** - Linked list utilities for data structures
   - **linux.c** - Linux-specific system calls and operations
   - **solaris.c** - Solaris-specific system calls and operations
   - **free.c** - Memory management and cleanup
   - **prop.c** - Property/attribute management
   - **nodes.c** - Node data structure management
   - **tracker.c** - Resource and operation tracking

### Execution Flow

```
User Input
    ↓
[Lexical Analyzer] (lex.yy) → Tokens
    ↓
[Parser] (TranSh.tab) → AST
    ↓
[Main Shell] (main.c) → Command Execution
    ↓
[Transaction Engine] (tran.c)
    ├─ File Operations (file.c)
    ├─ Block Operations (block.c)
    ├─ List Management (list.c)
    ├─ Resource Tracking (tracker.c)
    └─ Platform-specific Ops (linux.c/solaris.c)
    ↓
Resource Cleanup (free.c)
```

## Building

TranSh is compiled from C source files using a Makefile configuration:

```bash
make              # Build the executable
make clean        # Remove compiled objects
make rebuild      # Clean and rebuild
```

### Dependencies

- **gcc/clang** - C compiler
- **flex** - Lexical analyzer generator
- **bison** - Parser generator
- **POSIX-compliant system** (Linux/Solaris)

## Usage

```bash
./TranSh [options]
```

### Basic Commands

TranSh supports transaction-oriented commands:

- **Transaction Commands**: Begin, commit, rollback operations
- **File Commands**: Create, read, write, delete files within transactions
- **Block Commands**: Manipulate block-level structures
- **Query Commands**: View transaction state and resources

### Example Usage

```bash
BEGIN TRANSACTION
CREATE FILE "data.txt"
WRITE FILE "data.txt" "transaction data"
COMMIT
```

## Platform Support

### Linux
- Uses native Linux system calls
- Full support for Linux file systems
- Optimized for Linux process management

### Solaris
- Compatibility layer for Solaris systems
- Support for Solaris-specific system calls
- Adapted file system operations

## Key Features

### Transaction Management
- **ACID Properties**: Atomicity, Consistency, Isolation, Durability
- **Rollback Support**: Undo failed or unwanted operations
- **Nested Transactions**: Support for transaction hierarchies

### Resource Tracking
- Maintains comprehensive logs of all operations
- Tracks file handles and system resources
- Prevents resource leaks through automatic cleanup

### Memory Management
- Careful memory allocation and deallocation
- No memory leaks in transaction processing
- Efficient data structure management

### Error Handling
- Robust error detection and reporting
- Transaction rollback on errors
- Detailed error messaging

## File Structure

```
TranSh/
├── main.c              # Entry point and main loop
├── tran.c              # Transaction engine
├── file.c              # File operations
├── block.c             # Block operations
├── list.c              # List data structures
├── linux.c             # Linux-specific code
├── solaris.c           # Solaris-specific code
├── free.c              # Memory management
├── prop.c              # Property management
├── nodes.c             # Node structures
├── tracker.c           # Operation tracking
├── TranSh.l            # Flex lexer definition
├── TranSh.y            # Bison parser definition
├── Makefile            # Build configuration
└── README.md           # This file
```

## Troubleshooting

### Compilation Issues
- Ensure flex and bison are installed: `apt-get install flex bison`
- Check that gcc/clang is available on your system
- Verify POSIX compliance of your operating system

### Runtime Issues
- Check transaction logs for detailed error messages
- Verify file permissions for transaction operations
- Ensure sufficient disk space for transaction data

## Development Notes

### Adding New Operations
1. Define lexer tokens in `TranSh.l`
2. Add grammar rules in `TranSh.y`
3. Implement operation handler in appropriate module (file.c, block.c, etc.)
4. Add platform-specific code in linux.c/solaris.c if needed

### Memory Considerations
- All allocated memory must be freed in free.c
- Use proper cleanup handlers for error conditions
- Test with memory profiling tools (valgrind, etc.)

## Performance

TranSh is optimized for:
- Fast transaction commitment
- Minimal memory overhead
- Efficient file system operations
- Scalable resource tracking

---

**Version**: 1.0  
**Last Updated**: December 2022  
**Platform Support**: Linux, Solaris
