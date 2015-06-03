
import bpy
import os
import re
from mathutils import Matrix, Vector
from math import sin, cos, pi, sqrt

ENGINE='CYCLES'
bpy.context.scene.render.engine = ENGINE

def clear_materials():
    for material in bpy.data.materials:
        material.user_clear();
        bpy.data.materials.remove(material);
#clear_materials()


#from bmad_blender import elements


def emission_material(name, strength=50):
    mat=bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes=mat.node_tree.nodes
    for n in nodes: # Clear out default nodes
        nodes.remove(n)
    node = nodes.new(type='ShaderNodeEmission')  
    #node_emission.inputs[0].default_value = (0,1,0,1)  # green RGBA
    node.inputs[1].default_value = strength # strength
    #node_emission.location = 0,0
    node_output = nodes.new(type='ShaderNodeOutputMaterial')    
    node_output.location = 400,0
    links = mat.node_tree.links
    link = links.new(node_output.inputs[0],node.outputs[0])  
    return mat
  
def diffuse_material(name, color=(1,0,0,1)):
    mat=bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes=mat.node_tree.nodes
    for n in nodes: # Clear out default nodes
        nodes.remove(n)
    node = nodes.new(type='ShaderNodeBsdfDiffuse')  
    node.inputs[0].default_value = color 
    #node.inputs[1].default_value = strength # strength
    #node_emission.location = 0,0
    node_output = nodes.new(type='ShaderNodeOutputMaterial')    
    node_output.location = 400,0
    links = mat.node_tree.links
    link = links.new(node_output.inputs[0],node.outputs[0])    
    return mat
  
LIGHT_MATERIAL=emission_material('light', strength=100)
#TEST=diffuse_material('test')


def ele_material(ele):
    key = ele['key']
    name = key+'_material'
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    return diffuse_material(name, color=ele_color(ele)+tuple([1]))
   

def clear_objects():
  bpy.ops.object.mode_set(mode='OBJECT')
  bpy.ops.object.select_by_type(type='MESH')
  bpy.ops.object.delete(use_global=False)
  bpy.ops.object.select_by_type(type='LAMP')
  bpy.ops.object.delete(use_global=False)  
  #for item in bpy.data.meshes:
#    bpy.data.meshes.remove(item)
    
#clear_objects()



def map_table_dict(line):
    d = {}
    vals = line.split(',')[0:14]
    #d['layer']  = vals[0].strip()
    d['name']   = vals[0].strip()
    d['index']  = int(vals[1])
    d['x']      = float(vals[2])
    d['y']      = float(vals[3])
    d['z']      = float(vals[4])
    d['theta']  = float(vals[5])
    d['phi']    = float(vals[6])
    d['psi']    = float(vals[7])
    d['key']    = vals[8].strip()
    d['L']      = float(vals[9])  
    if d['key']=='SBEND':
        d['angle'] = float(vals[10]) 
        d['e1'] = float(vals[11]) 
        d['e2'] = float(vals[12])  
    d['descrip'] = vals[13]  
    return d

def blendfile(ele):
    match = re.search('3DMODEL=(.+?).blend', ele['descrip'])
    if match:
        return match.group(1)+'.blend'
    else:
        return None

def import_lattice(file):
    f = open(file, 'r')
    header=f.readline()
    lat = [map_table_dict(line) for line in f]
    f.close()
    return lat

def ele_x_scale(ele):
  sc = 0.1
  fac = 0.7
  if ele['key'] == 'E_GUN':
    sc = 0.4      
  if ele['key'] == 'PIPE':
    sc = 0.02
  if ele['key'] == 'DRIFT':
    sc = 0.03     
  if ele['key'] == 'SBEND':
    sc = 0.1*fac
  if ele['key'] == 'QUADRUPOLE':    
    sc = 0.1*fac
  if ele['key'] == 'SEXTUPOLE':    
    sc = 0.15*fac  
  if ele['key'] == 'LCAVITY':    
    sc = 0.2*fac  
  if ele['key'] == 'RFCAVITY':    
    sc = 0.2*fac      
  if ele['key'] == 'SOLENOID':    
    sc = 0.1*fac      
  if ele['key'] == 'WIGGLER':    
    sc = 0.3       
  if ele['name']=='DU.DUM01':
    sc = 0.4   
  return sc

def ele_color(ele):
  color = (0,0,0)
  if ele['key'] == 'E_GUN':
    color = (0.5, 0.5, 0.5)  
  if ele['key'] == 'SBEND':
    color = (1,0,0)
  if ele['key'] == 'QUADRUPOLE':
    color = (0,0,1)    
  if ele['key'] == 'LCAVITY':
    color = (0,1,0) 
  if ele['key'] == 'RFCAVITY':
    color = (0,1,0) 
  if ele['key'] == 'SOLENOID':
    color = (1,0,1) #purple         
  if ele['key'] == 'SEXTUPOLE':
    color = (1,1,0)     # yellow   
  if ele['key'] == 'WIGGLER':
    color = (1,0.4,0)     # orange?           
  if ele['name']=='DU.DUM01':
    color = (0.5, 0.5, 0.5)  
  return color


def ele_section():
    return 0
    
def faces_from(sections, closed=True):
    """
    A section is a list of vertices that defines a cross-section of an element
    This makes rectangle faces
    """
    nix = [len(s) for s in sections]
    if len(set(nix)) >1:
        print('ERROR: sections must have the same number of points')
        return
    n = nix[0]
    faces = []
    for i0 in range(len(sections) -1):
        for j in range(n-1):
            faces.append( (i0*n + j, (i0+1)*n +j, (i0+1)*n +j+1, i0*n +j+1) )
        faces.append((i0*n +n-1, (i0+1)*n +n-1, (i0+1)*n, i0*n))
    if closed:
        faces.append(range(n)) #first section
        faces.append(range((len(sections)-1)*n, (len(sections)-1)*n+n)) # Last section
    return faces  
    
def box_section(X, haperture, vaperture):
    return ( (X, haperture, vaperture), (X, -haperture, vaperture), (X, -haperture, -vaperture), (X, haperture, -vaperture))

def ellipse_section(X, haperture, vaperture, n=30):
    angles = [2*pi*i/n for i in range(n)]
    return [ (X, haperture*cos(a), vaperture*sin(a)) for a in angles]

def multipole_section(X, aperture, n):
    angles = [pi*i/n + pi/(2*n) for i in range(2*n)]
    return [ (X, aperture*cos(a), aperture*sin(a)) for a in angles]

def ele_section(s_rel, ele):
    # Make sections relatice to center of element
    sc = ele_x_scale(ele)
    if ele['key'] == 'QUADRUPOLE':
        return multipole_section(s_rel, sc, 4) 
    if ele['key'] == 'SEXTUPOLE':
        return multipole_section(s_rel, sc, 6)     
    elif ele['key'] == 'SBEND':
        
        a = ele['angle']
        if abs(a) < 1e-5 or abs(ele['L']) < 1e-5:
            return box_section(s_rel, sc, sc) 
        L = ele['L']
        rho = L/a
        # Baseline section
        s0 = box_section(0, sc, sc)
        # Edge angle
        f = s_rel/L+0.5
        edge =  ele['e2']*f + (-1)*ele['e1']*(1-f)
        m0=Matrix.Rotation(edge, 4, 'Z')
        m1=Matrix.Translation((0, rho, 0))
        m2=Matrix.Rotation(-s_rel/rho, 4, 'Z')
        m3=Matrix.Translation((0, -rho, 0))
        m=m3*m2*m1*m0
        sec=[]
        for p in s0:
            v = m*Vector(p)
            sec.append(v[:])
        return sec
        
    elif ele['key'] == 'WIGGLER':
        return box_section(s_rel, sc, 2*sc)    
    else:
        return ellipse_section(s_rel, sc, sc)

def ele_mesh(ele):
    name = ele['name']
    L = ele['L']
    if ele['key'] == 'SBEND':
        n=20
        slist = [L*i/(n-1) - L/2 for i in range(n)]
    else:
        slist = [-L/2, L/2]
    sections = [ele_section(s_rel, ele) for s_rel in slist]
    faces = faces_from(sections)
    verts = []
    for s in sections:
        for p in s:
            verts.append(p)
            
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    return mesh


def load_blend(filepath):
    '''
    Load .blend model objects.
    '''
    with bpy.data.libraries.load(filepath, link=False) as (data_from, data_to):    
        onames = [name for name in data_from.objects if True]
        print('Library: ', filepath)
        print('         has objects', onames)
        data_to.objects = data_from.objects
    return data_to.objects



def add_children_from_blend(parent, blendfilepath, libdict):
    if blendfilepath in libdict:
        print('Library already loaded: ', blendfilepath)
        print('Data will be linked')
        # Library has already been loaded. Copy meshes and materials
        children = []
        for o in libdict[blendfilepath]:
            child = bpy.data.objects.new(o.name, o.data)
            child.location = o.location
            child.rotation_euler = o.rotation_euler
            children.append(child)
    else:
        print('New library: ', blendfilepath)
        children = load_blend(blendfilepath)  
        libdict[blendfilepath] = children
    for child in children:
        bpy.context.scene.objects.link(child)
        child.parent = parent         


#basename = 'erl0.lat'
#basename = 'cesr_upgrade'
basename = 'lat_1'
#basename = 'erl_1pass.lat'
#basename = 'lat_1'
#basename='basics'
#basename = 'simple_arc'
#ROOT='C:\\Users\\Chrisonian\\Dropbox\\Blender\\'
ROOT='/home/dcs16/xray/reu2015/'
CATALOGUE=ROOT+'Catalogue/'
file = ROOT+basename+'.layout_table'
print('IMPORTING: ', file)
lat = import_lattice(file)    

REALMODELSON = True

LIBDICT={}
def ele_object(ele):
    name = ele['name']
    mesh = ele_mesh(ele)

    object = bpy.data.objects.new(name, mesh)
    bpy.context.scene.objects.link(object)
    object.location = (0, 0, 0) 
    bfile=blendfile(ele)
    if bfile and REALMODELSON:
        f=CATALOGUE+bfile
        if os.path.isfile(f):
            print('blend file: ', f, 'exists!')
            add_children_from_blend(object, f, LIBDICT)
            # Hide to see children only:
            object.hide = True
            object.hide_render = True
        else:
            print('Blend file missing: ', f)
            
    mat = ele_material(ele)
    #print('color: ', color)
    #mat.diffuse_color = ele_color(ele)
    object.data.materials.append(mat)
    return object

    #bpy.context.scene.objects.link(object)
    



def lat_borders(lat, dim='x'):
  xlist = [ele[dim] for ele in lat]
  return min(xlist), max(xlist)
  
Xborders = lat_borders(lat, 'z')
Yborders = lat_borders(lat, 'x')
Zborders = lat_borders(lat, 'y')

Xcenter =  sum(Xborders )/2
Ycenter =  sum(Yborders )/2 
Zcenter =  -45*0.0254 #sum(Zborders )/2 -1

# Fudge for L0E
Xcenter = 15.403412220000002 -4 + 1.67 -.16155
Ycenter = -7.305905715 
Zcenter = -1.143

for ele in lat:
  #print(ele)
  if ele['L'] == 0:
    continue
  #cubeobject(location=( ele['z']-Xcenter - math.cos(theta)*ele['L']/2, ele['x']-Ycenter- math.sin(theta)*ele['L']/2, ele['y']-Zcenter))
  ob = ele_object(ele)
  
  #ob.select=True
  ob.rotation_euler.z =  ele['theta']
  ob.rotation_euler.y = -ele['phi']
  ob.rotation_euler.x =  ele['psi']
  #ob.rotation = (theta, 0, 0)
  #bpy.ops.transform.rotate(value=ele['psi'], axis = (1,0,0)) 
  #bpy.ops.transform.rotate(value=-ele['phi'], axis = (0,1,0)) 
  #bpy.ops.transform.rotate(value=ele['theta'], axis = (0,0,1)) 
  
  ob.location=( ele['z']-Xcenter, ele['x']-Ycenter, ele['y']-Zcenter)
  ob.name = ele['name']
  #ob.select=False
  #print(ele['name'], ele['theta']*180/pi, ele['phi']*180/pi, ele['psi']*180/pi)
  
  
def camera_at(d):
  cam = bpy.data.objects['Camera'] # bpy.types.Camera
  cam.location.x = 0.0
  cam.location.y = -d/sqrt(2)
  cam.location.z = d/sqrt(2)
  cam.rotation_euler.x = pi/4
  cam.rotation_euler.y = 0
  cam.rotation_euler.z = 0

def ortho_camera_at(z, scale):
  cam = bpy.data.objects['Camera'] # bpy.types.Camera
  cam.data.type = 'ORTHO'
  cam.location.x = 0.0
  cam.location.y = 0
  cam.location.z = z
  cam.rotation_euler.x = 0
  cam.rotation_euler.y = 0
  cam.rotation_euler.z = 0
  cam.data.ortho_scale = scale
 


def lamp_energy(energy):
  lamp = bpy.data.objects['Lamp']
  lamp.location.z = 10
  lamp.data.energy = energy


def lighting(x,y,z):
    bpy.ops.mesh.primitive_plane_add(location=(x,y,z))
    bpy.context.active_object.data.materials.append(LIGHT_MATERIAL)

def sun(strength):
    #bpy.data.node_groups["Shader Nodetree"].nodes["Emission"].inputs[1].default_value = 0.8
    bpy.ops.object.lamp_add(type='SUN', view_align=False, location=(0, 0, 10) )
    bpy.context.active_object.data.node_tree.nodes["Emission"].inputs[1].default_value = strength

camera_at(45)
delta = (Xborders[1]-Xborders[0])/4


#sun(4)
#lighting( delta, 0, 15)
#lighting(-delta, 0, 15)



#ttest()
#lamp_energy(10)

# Floor
def make_floor():
    bpy.ops.mesh.primitive_plane_add(location=(0,0,0))  
    bpy.context.object.scale[0] = 20
    bpy.context.object.scale[1] = 10    
    mat = diffuse_material('floor_material', color=(.2,.2,.2,1))
    bpy.context.active_object.data.materials.append(mat)

#make_floor()
  
print('XYZ centers: ', Xcenter, Ycenter, Zcenter)  
  
bpy.context.scene.render.filepath = ROOT+basename+".png"
bpy.context.scene.render.resolution_percentage = 100
#bpy.ops.render.render(use_viewport = True, write_still=True)

#ortho_camera_at(10, 35)
#bpy.context.scene.render.filepath = ROOT+basename+"_ortho.png"
#bpy.ops.render.render(use_viewport = True, write_still=True)
