/*
Custom 3D Engine sphere by
Daniel Koopmans 1688960
*/

import java.util.*;
import processing.pdf.*;

Engine3D engine = new Engine3D(); //Initiliazing the custom 3D Engine
Sphere3D innerSphere = new Sphere3D(0.5f); //Create sphere shape with radius/size 0.5
Sphere3D outerSphere = new Sphere3D(2f); //Create sphere shape with radius/size 2

void setup() {
  size(1920, 1080, PDF, "picture.pdf");
  strokeWeight(0.1f);
  stroke(255);
  noLoop();
  engine.updateProjectionMatrix(); //Pre-initializing the projectionMatrix to enchance performace.
  outerSphere
    .setXRotation(0.5 * PI); //Rotating the entire shpere 90° around its X-Axis.
  innerSphere
    .setXRotation(0.5 * PI) //Rotating the entire shpere 90° around its X-Axis.
    .setYRotation(0.25 * PI).setTranslation(new Vector3D(0,0,-0.5)); //Rotating the entire shpere 45° around its Y-Axis.
}

void draw() {
  background(0);
  this.engine.drawShape(innerSphere); //Storing the shape in the vertex buffer.
  this.engine.drawShape(outerSphere); //Storing the shape in the vertex buffer.
  engine.processBuffer(); //Sorting the processing the buffer on the screen.
  exit();
}

class Engine3D {

  Vector3D eyeLocation = new Vector3D(0, 0, -1.6);
  List<Triangle> Vertexbuffer = new ArrayList<Triangle>(); //Buffer for the all vertexes to be processed later
  
  float[][] projectionMatrix;
  float aspectRatio;
  float fovRad;
  float near;
  float far;
  float fov;

  public Engine3D() {
    this(90.0f, 1000.0f, 0.1f);
  }

  public Engine3D(float fov, float far, float near) {
    this.near = near;
    this.far = far;
    this.fov = fov;
  }
  
  public void shiftToBuffer(Triangle triangle) {
    this.Vertexbuffer.add(triangle); //Adds the vertex to the buffer to be drawn on the screen after all objects are inside the buffer or the buffer is flushed.
  }
  
  public void processBuffer() {    
    this.Vertexbuffer.sort((s1, s2)->Float.compare(s2.getAverageZ(), s1.getAverageZ())); //Sort the vertex list to draw the items the furthest away first to avoid reverse overlap. 
    this.Vertexbuffer.forEach(triangle->{
      Vector3D[] vectors = triangle.getVectors();
      for(int x = 0; x < vectors.length; x++) {
        if((vectors[x].getZ() - eyeLocation.getZ()) <= 0) return; //Skips vertexes that are behind the eyeLocation (camera).
        applyProjectionMatrix(vectors[x].subtract(eyeLocation)); //Apply the normalized projection matrix (perspective matrix) on the translated vector to add perspective.
      }
      fill(triangle.getRGBA()); //Fill the shape with the provided color.
      beginShape(TRIANGLES); //Start drawing the shape.
      for(Vector3D vec : vectors) {
        denormalizeVector(vec); //Denormalize vector by multiplying the vector by the ratio of screen size to the matrix domain and range [-1,1]. So it becomes [0, screenWidth] and [0, screenHeight].
        vertex(vec.getX(), vec.getY()); //Draw vertex.
      }
      endShape(); //Printing the vertex on the screen
    });
    this.Vertexbuffer.clear(); //Clearing the cloned vertex buffer for the next frame.
  }
  
  public void drawShape(Shape3D shape) {
    shape.drawShape(this); //Puts the shape into a buffer to be drawn later
  }
  
  private Vector3D denormalizeVector(Vector3D vec) {
    float x = (vec.getX() + 1.0f) * (width/2); //Shifting and multiplying domain [-1, 1] to [0,2] so it becomes positive since the domain of screenWidth is [0, width]
    float y = (vec.getY() + 1.0f) * (height/2); //Shifting and multiplying domain [-1, 1] to [0,2] so it becomes positive since the domain of screenHeight is [0, height]
    return vec.set(x, y, 0);
  }
  
  private Vector3D applyProjectionMatrix(Vector3D vec) {
    float x = projectionMatrix[0][0] * vec.getX() + projectionMatrix[1][0] * vec.getY() + projectionMatrix[2][0] * vec.getZ() + projectionMatrix[3][0]; //Projection matrix multiplication to obtain x
    float y = projectionMatrix[0][1] * vec.getX() + projectionMatrix[1][1] * vec.getY() + projectionMatrix[2][1] * vec.getZ() + projectionMatrix[3][1]; //Projection matrix multiplication to obtain y
    float z = projectionMatrix[0][2] * vec.getX() + projectionMatrix[1][2] * vec.getY() + projectionMatrix[2][2] * vec.getZ() + projectionMatrix[3][2]; //Projection matrix multiplication to obtain z
    float w = projectionMatrix[0][3] * vec.getX() + projectionMatrix[1][3] * vec.getY() + projectionMatrix[2][3] * vec.getZ() + projectionMatrix[3][3]; //Projection matrix multiplication to obtain w
    if(w != 0.0f) {
      x /= w;
      y /= w;
      z /= w;
    } //Fixing the x,y,z cordinates by dividing them with the outcome of matrix * (w = -z)
    return vec.set(x,y,z);
  }

  public void updateProjectionMatrix() {
    this.aspectRatio = ((float)height)/width; //Creating the aspectRatio for the multiplcation with Field of View (FOV)
    this.fovRad = 1.0f / tan((PI / 180.0f) * fov * 0.5f); //Converting the FOV in degrees to radians.
    this.projectionMatrix = new float[][] {
      {aspectRatio*fovRad, 0, 0, 0},
      {0, fovRad, 0, 0},
      {0, 0, far/(far-near), 1},
      {0, 0, (-far*near)/(far-near), 0}
    }; //Creating the projection matrix
  }

  public void setFov(float fov) {
    this.fov = fov;
    this.updateProjectionMatrix();
  }

  public void setNear(float near) {
    this.near = near;
    this.updateProjectionMatrix();
  }

  public void setFar(float far) {
    this.far = far;
    this.updateProjectionMatrix();
  }

  public Vector3D getEyeLocation() {
    return this.eyeLocation;
  }
}

class Sphere3D implements Shape3D {
  
  private final List<Triangle> shaderCache = new ArrayList<Triangle>(); //Shader cache to enhance performance by creating a shader only once and cloning the list for processing to become reusable
  private final float size; //Size of the sphere
  private final int iterations = 30; //Amount of iterations of the sphere, the higher the smoother the sphere.
  private final float part = PI / iterations; //Part equals PI divided by the amount of iterations, the lower the smoother
  private final Vector3D location = new Vector3D(0,0,0); //Translation coordinates of the sphere
  private final Vector3D rotation = new Vector3D(0,0,0); //Rotation values of the sphere
  
  //Constructor with size/radius of the sphere
  public Sphere3D(float size) {
    this.size = size;
  }
  
  //Set translation coordinates values when the shader cache is processed
  public Sphere3D setTranslation(Vector3D location) {
    this.location.set(location.getX(), location.getY(), location.getZ());
    return this;
  }
  
  //Set X-axis rotation value when the shader cache is processed
  public Sphere3D setXRotation(float angle) {
    this.rotation.setX(angle);
    return this;
  }
  
  //Set Y-axis rotation value when the shader cache is processed
  public Sphere3D setYRotation(float angle) {
    this.rotation.setY(angle);
    return this;
  }
  
  //Set Z-axis rotation value when the shader cache is processed
  public Sphere3D setZRotation(float angle) {
    this.rotation.setZ(angle);
    return this;
  }
  
  public void drawShape(Engine3D engine) {
    if(this.shaderCache.isEmpty()) this.loadShaderCache(); //Generates the scalable sphere vertex coordinations.
    for(Triangle triangle : this.shaderCache) {
      Triangle clone = triangle.clone(); //Clone the vertix so the program does not have to regenerate the generated sphere shader each time when applying translations or rotations to enchance performance
      if(this.rotation.getX() != 0) clone.rotateX(this.rotation.getX()); //Rotates cloned object around it's X-Axis if needed
      if(this.rotation.getY() != 0) clone.rotateY(this.rotation.getY()); //Rotates cloned object around it's Y-Axis if needed
      if(this.rotation.getZ() != 0) clone.rotateZ(this.rotation.getZ()); //Rotates cloned object around it's Z-Axis if needed
      clone.translate(this.location); //Translate the cloned object
      engine.shiftToBuffer(clone); //Puts the vertixes into the buffer for later
    }
  }
  
  public void loadShaderCache() {
    this.shaderCache.clear();
    for (float t = 0; t <= PI; t += part) {
        float y = cos(t) * size; //The Y-coordinate of the sphere
        float w = sin(t) * size; //The radius value of each row (y)
        
        float y1 = cos(t + part) * size; //The Y-coordinate for the next row
        float w1 = sin(t + part) * size; //The radius value for the next row
        
        for (float i = 0; i <= TWO_PI; i += part) {               
            float x = cos(i) * w; //The X-value of the y row scaled by radius w
            float z = sin(i) * w; //The Z-value of the y row scaled by radius w
            float x1 = cos(i) * w1; //The X-value of the (y + 1) row scaled by radius w
            float z1 = sin(i) * w1; //The Z-value of the (y + 1) row scaled by radius w
            float x2 = cos(i + part) * w1;  //The next X-value of the (y + 1) row and (x + 1) scaled by next radius (w + 1)
            float z2 = sin(i + part) * w1;  //The next Z-value of the (y + 1) row and (z + 1) scaled by next radius (w + 1)
            float x3 = cos(i + part) * w; //The next X-value of the y row and (x + 1) scaled by radius w
            float z3 = sin(i + part) * w; //The next Z-value of the y row and (z + 1) scaled by radius w
            
            float colorFactor = ((cos(i) + 1) / 2) * 50 + ((cos(t * 2) + 1) / 2) * 155 + 50; //Adding blue gradient for the sphere
            int red = (int)(110 + 0.3 * colorFactor); //Applying the gradient factor
            int green = (int)(186 + 0.3 * colorFactor); //Applying the gradient factor
            int blue = 245; //Blue baseline
            this.shaderCache.add(
              new Triangle(
                new Vector3D(x, y, z), 
                new Vector3D(x1, y1, z1), 
                new Vector3D(x3, y, z3), 
                red, green, blue
              )
            );//Adding triangle to the shader cache
            this.shaderCache.add(
              new Triangle(
                new Vector3D(x1, y1, z1), 
                new Vector3D(x3, y, z3), 
                new Vector3D(x2, y1, z2), 
                red, green, blue
              )
            );//Adding triangle to the shader cache
        }
    }
  }
  
}

class Triangle {
  
  private final Vector3D[] vectors;
  private final int rgba;
  
  public Triangle(Vector3D v1, Vector3D v2, Vector3D v3) {
    this(v1, v2, v3, 255, 255, 255);
  }
  
  public Triangle(Vector3D v1, Vector3D v2, Vector3D v3, int red, int green, int blue) {
    this(v1, v2, v3, red, green, blue, 255);
  }
  
  public Triangle(Vector3D v1, Vector3D v2, Vector3D v3, int red, int green, int blue, int alpha) {
    this(v1, v2, v3, color(red, green, blue, alpha));
  }
  
  public Triangle(Vector3D v1, Vector3D v2, Vector3D v3, int rgba) {
    this.vectors = new Vector3D[] {v1, v2, v3};
    this.rgba = rgba;
  }
  
  //Get the average Z value of all vectors to draw the furthest object away from camera first.
  public float getAverageZ() {
    float z = 0.0f;
    for(Vector3D vector : this.vectors) {
        z+=vector.getZ();
    }
    return z/3.0f;
  }
  
  //Translate the Triangle shape on 3D space
  public Triangle translate(Vector3D vector) {
    for(Vector3D vec : this.vectors) {
      vec.add(vector);
    }
    return this;
  }
  
  //Rotate all vectors of the Triangle around its X-Axis
  public Triangle rotateX(float angle) {
    for(Vector3D vec : this.vectors) {
      vec.rotateX(angle);
    }  
    return this;
  }
  
  //Rotate all vectors of the Triangle around its Y-Axis
  public Triangle rotateY(float angle) {
    for(Vector3D vec : this.vectors) {
      vec.rotateY(angle);
    }  
    return this;
  }
  
  //Rotate all vectors of the Triangle around its Z-Axis
  public Triangle rotateZ(float angle) {
    for(Vector3D vec : this.vectors) {
      vec.rotateZ(angle);
    }  
    return this;
  }
  
  //Multiply all vectors of the Triangle with a factor
  public Triangle multiply(float factor) {
    for(Vector3D vec : this.vectors) {
      vec.multiply(factor);
    }  
    return this;
  }
  
  public int getRGBA() {
    return this.rgba;
  }
  
  public Vector3D[] getVectors() {
    return this.vectors;
  }
  
  //Clone all the vectors of the triangle
  public Triangle clone() {
    return new Triangle(this.vectors[0].clone(), this.vectors[1].clone(), this.vectors[2].clone(), this.rgba);
  }
}

class Vector3D {

  private float x;
  private float y;
  private float z;

  public Vector3D(float x, float y, float z) {
    this.x = x;
    this.y = y;
    this.z = z;
  }
  
  //Add two vectors together
  public Vector3D add(Vector3D vec) {
    return add(vec.x, vec.y, vec.z);
  }

  //Add multiple coordinates to the vector 
  public Vector3D add(float x, float y, float z) {
    this.x += x;
    this.y += y;
    this.z += z;
    return this;
  }

  //Substract/translate the vector 
  public Vector3D subtract(float x, float y, float z) {
    this.x -= x;
    this.y -= y;
    this.z -= z;
    return this;
  }
  
  //Substract/translate by another vector 
  public Vector3D subtract(Vector3D vec) {
    return subtract(vec.x, vec.y, vec.z);
  }

  //Multiply the vector by a factor
  public Vector3D multiply(float factor) {
    this.x *= factor;
    this.y *= factor;
    this.z *= factor;
    return this;
  }
  
  //Divide the vector by a factor
  public Vector3D divide(float factor) {
    this.x /= factor;
    this.y /= factor;
    this.z /= factor;
    return this;
  }

  public Vector3D rotateX(float a) {
    float sin = sin(a); //Calculate sin once to enhance performance.
    float cos = cos(a); //Calculate cos once to enhance performance.
    float y = (cos * this.y) - (sin * this.z); //Applying the 3D Rotation matrix to obtain Y-Coordinate
    float z = (sin * this.y) + (cos * this.z); //Applying the 3D Rotation matrix to obtain Z-Coordinate
    this.y = y;
    this.z = z;
    return this;
  }

  public Vector3D rotateY(float a) {
    float sin = sin(a); //Calculate sin once to enhance performance.
    float cos = cos(a); //Calculate cos once to enhance performance.
    float x = (cos * this.x) + (sin * this.z); //Applying the 3D Rotation matrix to obtain X-Coordinate
    float z = (-sin * this.x) + (cos * this.z); //Applying the 3D Rotation matrix to obtain Z-Coordinate
    this.x = x;
    this.z = z;
    return this;
  }

  //Rotate the vector around it's Z-axis.
  public Vector3D rotateZ(float a) {
    float sin = sin(a); //Calculate sin once to enhance performance.
    float cos = cos(a); //Calculate cos once to enhance performance.
    float x = (cos * this.x) - (sin * this.y); //Applying the 3D Rotation matrix to obtain X-Coordinate
    float y = (sin * this.x) + (cos * this.y); //Applying the 3D Rotation matrix to obtain Y-Coordinate
    this.x = x;
    this.y = y;
    return this;
  }
  
  //Sets the XYZ-Coordinate
  public Vector3D set(float x, float y, float z) {
    this.x = x;
    this.y = y;
    this.z = z;
    return this;
  }
   
  //Sets the X-Coordinate
  public void setX(float x) {
    this.x = x;
  }
  
  //Sets the Y-Coordinate
  public void setY(float y) {
    this.y = y;
  }
  
  //Sets the Z-Coordinate
  public void setZ(float z) {
    this.z = z;
  }
  
  //Get the distance between two points (Vectors)
  public float distance(Vector3D vector) {
    return sqrt(sq(vector.getX() - this.x) + sq(vector.getY() - this.y) + sq(vector.getZ() - this.z));
  }
  
  //Get the length of an 3D vector
  public float getLength() {
    return sqrt(sq(this.x) + sq(this.y) + sq(this.z));
  }
  
  //Get the X-Coordinate of the 3D Vector
  public float getX() {
    return this.x;
  }
  
  //Get the Y-Coordinate of the 3D Vector
  public float getY() {
    return this.y;
  }
  
  //Get the Z-Coordinate of the 3D Vector
  public float getZ() {
    return this.z;
  }
  
  //Clone the vector to prevent changing the original vector
  public Vector3D clone() {
    return new Vector3D(this.x, this.y, this.z);
  }
  
}

public interface Shape3D {

  void drawShape(Engine3D engine);
  
}
