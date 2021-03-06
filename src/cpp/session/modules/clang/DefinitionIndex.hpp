/*
 * DefinitionIndex.hpp
 *
 * Copyright (C) 2009-12 by RStudio, Inc.
 *
 * Unless you have received this program directly from RStudio pursuant
 * to the terms of a commercial license agreement with RStudio, then
 * this program is licensed to you under the terms of version 3 of the
 * GNU Affero General Public License. This program is distributed WITHOUT
 * ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING THOSE OF NON-INFRINGEMENT,
 * MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. Please refer to the
 * AGPL (http://www.gnu.org/licenses/agpl-3.0.txt) for more details.
 *
 */

#ifndef SESSION_MODULES_CLANG_DEFINITION_INDEX_HPP
#define SESSION_MODULES_CLANG_DEFINITION_INDEX_HPP

#include <string>
#include <iosfwd>

#include <core/FilePath.hpp>
#include <core/libclang/LibClang.hpp>

namespace core {
   class Error;
}

namespace session {
namespace modules {      
namespace clang {

// definition type
enum CppDefinitionKind
{
   CppInvalidDefinition = 0,
   CppNamespaceDefinition = 1,
   CppClassDefinition = 2,
   CppStructDefinition = 3,
   CppEnumDefinition = 4,
   CppFunctionDefinition = 5,
   CppMemberFunctionDefinition = 6
};

// source location
struct FileLocation
{
   FileLocation()
      : line(0), column(0)
   {
   }

   FileLocation(const core::FilePath& filePath, unsigned line, unsigned column)
      : filePath(filePath), line(line), column(column)
   {
   }

   bool empty() const { return filePath.empty(); }

   core::FilePath filePath;
   unsigned line;
   unsigned column;
};

// C++ symbol definition
struct CppDefinition
{
   CppDefinition()
      : kind(CppInvalidDefinition)
   {
   }

   CppDefinition(const std::string& USR,
                 CppDefinitionKind kind,
                 const std::string& parentName,
                 const std::string& name,
                 const FileLocation& location)
      : USR(USR),
        kind(kind),
        parentName(parentName),
        name(name),
        location(location)
   {
   }

   bool empty() const { return name.empty(); }

   std::string USR;
   CppDefinitionKind kind;
   std::string parentName; // e.g. containing C++ class
   std::string name;
   FileLocation location;
};

std::ostream& operator<<(std::ostream& os, const CppDefinition& definition);

FileLocation findDefinitionLocation(const FileLocation& location);

void searchDefinitions(const std::string& term,
                       std::vector<CppDefinition>* pDefinitions);

core::Error initializeDefinitionIndex();

} // namespace clang
} // namepace modules
} // namesapce session

#endif // SESSION_MODULES_CLANG_DEFINITION_INDEX_HPP
